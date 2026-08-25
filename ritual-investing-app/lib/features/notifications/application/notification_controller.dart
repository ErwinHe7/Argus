// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api/financial_command_journal.dart';
import '../../../core/api/invalidation_bus.dart';
import '../../../core/api/pending_command_store.dart';
import '../../../core/api/view_state.dart';
import '../../../core/bootstrap/member_bootstrap.dart';
import '../../../core/cache/read_cache.dart';
import '../data/repository.dart';
import '../domain/model.dart';

enum NotificationPhase {
  idle,
  loading,
  empty,
  ready,
  stale,
  preferencesReview,
  preferenceConflict,
  readAllReview,
  restoredReview,
  reconciliationRequired,
  mutating,
  forbidden,
  throttled,
  retryableFailure,
  terminalFailure,
}

class NotificationController extends ChangeNotifier {
  NotificationController({
    required NotificationRepository repository,
    required PendingCommandStore pendingStore,
    required InvalidationBus invalidationBus,
    required this.scope,
    required String Function() createKey,
    required DateTime Function() now,
    MemberPersonalization personalization = const MemberPersonalization(),
  }) : _repository = repository,
       _now = now,
       _personalization = personalization,
       _journal = FinancialCommandJournal(
         store: pendingStore,
         scope: scope,
         createKey: createKey,
         now: now,
       ) {
    _invalidationSubscription = invalidationBus
        .eventsFor(scope)
        .listen(_handleInvalidation);
  }

  final NotificationRepository _repository;
  final DateTime Function() _now;
  final FinancialCommandJournal _journal;
  final CacheScope scope;
  late final StreamSubscription<InvalidationEvent> _invalidationSubscription;
  NotificationPhase _phase = NotificationPhase.idle;
  List<NotificationItem> _items = const [];
  NotificationPreferences? _preferences;
  NotificationPreferencesDraft? _preferenceDraft;
  NotificationPreferencesDraft? _preferenceRecoveryDraft;
  String? _nextCursor;
  bool _hasMore = false;
  bool _isStale = false;
  String? _message;
  DateTime? _readAllBefore;
  JournaledFinancialCommand? _protectedReadAll;
  MemberPersonalization _personalization;
  bool _disposed = false;

  NotificationPhase get phase => _phase;
  List<NotificationItem> get items => List.unmodifiable(_items);
  NotificationPreferences? get preferences => _preferences;
  NotificationPreferencesDraft? get preferenceDraft => _preferenceDraft;
  bool get hasMore => _hasMore;
  bool get isStale => _isStale;
  String? get message => _message;
  bool get hasProtectedReadAll => _protectedReadAll != null;
  bool get canReviewProtectedReadAll =>
      _protectedReadAll != null &&
      {
        NotificationPhase.restoredReview,
        NotificationPhase.retryableFailure,
        NotificationPhase.throttled,
        NotificationPhase.stale,
      }.contains(_phase);
  bool get externalDeliveryAvailable => false;
  String get operation => 'notifications.read-all';

  String get framingLabel => switch (_personalization.ritualVoice) {
    MemberRitualVoice.practical => 'Practical inbox framing',
    MemberRitualVoice.mystical => 'Symbolic inbox framing',
    MemberRitualVoice.balanced ||
    MemberRitualVoice.unavailable => 'Balanced inbox framing',
  };

  void updatePersonalization(MemberPersonalization value) {
    if (_personalization.ritualVoice == value.ritualVoice) return;
    _personalization = value;
    notifyListeners();
  }

  Future<void> load({bool preserveValue = false}) async {
    if (!preserveValue) {
      _phase = NotificationPhase.loading;
      _message = null;
      notifyListeners();
    }
    try {
      final page = await _repository.load(filter: NotificationReadFilter.all);
      final preferences = await _repository.getPreferences();
      _items = page.value.items;
      _nextCursor = page.value.nextCursor;
      _hasMore = page.value.hasMore;
      _preferences = preferences.value;
      _preferenceDraft ??= preferences.value.asDraft();
      _isStale = page.isStale || preferences.isStale;
      _phase = _isStale
          ? NotificationPhase.stale
          : _items.isEmpty
          ? NotificationPhase.empty
          : NotificationPhase.ready;
      _message = _isStale
          ? 'Showing cached in-app notices. Read state and preferences require an authoritative refresh.'
          : _items.isEmpty
          ? 'No in-app notices yet. External push delivery is not enabled.'
          : null;
      await _restoreReadAll();
    } on Object catch (error) {
      _mapFailure(error, preserveValue: preserveValue || _items.isNotEmpty);
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    final cursor = _nextCursor;
    if (!_hasMore || cursor == null) return;
    try {
      final page = await _repository.load(
        filter: NotificationReadFilter.all,
        cursor: cursor,
      );
      final known = _items.map((item) => item.id).toSet();
      _items = [
        ..._items,
        ...page.value.items.where((item) => known.add(item.id)),
      ];
      _nextCursor = page.value.nextCursor;
      _hasMore = page.value.hasMore;
      _isStale = _isStale || page.isStale;
      _phase = _isStale ? NotificationPhase.stale : NotificationPhase.ready;
    } on Object catch (error) {
      _mapFailure(error, preserveValue: true);
    }
    notifyListeners();
  }

  Future<void> setRead(String notificationId, bool read) async {
    if (_phase == NotificationPhase.mutating) return;
    final current = _items
        .where((item) => item.id == notificationId)
        .firstOrNull;
    if (current == null) return;
    _phase = NotificationPhase.mutating;
    _message = null;
    notifyListeners();
    try {
      final updated = await _repository.setRead(notificationId, read);
      if (updated.id != notificationId || updated.isRead != read) {
        throw const LoadFailure(LoadPhase.terminalFailure);
      }
      _items = _items
          .map((item) => item.id == notificationId ? updated : item)
          .toList(growable: false);
      _phase = NotificationPhase.ready;
    } on Object catch (error) {
      _mapFailure(error, preserveValue: true);
    }
    notifyListeners();
  }

  void editPreferences(NotificationPreferences value) {
    _preferenceDraft = value.asDraft();
    _phase = NotificationPhase.preferencesReview;
    _message = 'Review in-app recap preferences. These controls do not enable external push delivery.';
    notifyListeners();
  }

  void editPreferenceDraft(NotificationPreferencesDraft value) {
    _preferenceDraft = value;
    _phase = NotificationPhase.preferencesReview;
    notifyListeners();
  }

  Future<void> savePreferences() async {
    final current = _preferences;
    final draft = _preferenceDraft;
    if (current == null || draft == null) return;
    _phase = NotificationPhase.mutating;
    notifyListeners();
    try {
      final updated = await _repository.patchPreferences(
        draft,
        current.version,
      );
      if (updated.version <= current.version ||
          !draft.exactlyMatches(updated)) {
        throw const LoadFailure(LoadPhase.terminalFailure);
      }
      _preferences = updated;
      _preferenceDraft = updated.asDraft();
      _phase = _items.isEmpty
          ? NotificationPhase.empty
          : NotificationPhase.ready;
      _message =
          'Authoritative in-app preferences saved. Push remains unavailable.';
    } on Object catch (error) {
      if (error is AmbiguousNotificationPreferences ||
          (error is LoadFailure && error.phase == LoadPhase.conflict)) {
        await _reconcilePreferences(draft);
      } else {
        _mapFailure(error, preserveValue: true);
      }
    }
    notifyListeners();
  }

  void reviewPreferenceConflict() {
    if (_phase != NotificationPhase.preferenceConflict ||
        _preferenceDraft == null) {
      return;
    }
    _phase = NotificationPhase.preferencesReview;
    _message =
        'Review the preserved edits against the refreshed server preferences.';
    notifyListeners();
  }

  void prepareReadAll() {
    if (_protectedReadAll != null) {
      _message = 'Resolve the saved read-all review before starting another.';
      notifyListeners();
      return;
    }
    _readAllBefore = _now().toUtc();
    _phase = NotificationPhase.readAllReview;
    _message = 'Review marking all notices at or before this cutoff read, within the server command bound. Nothing submits automatically.';
    notifyListeners();
  }

  void reviewRestoredReadAll() {
    if (!canReviewProtectedReadAll) return;
    _phase = NotificationPhase.readAllReview;
    _message = 'Review the unchanged cutoff before the same-key retry.';
    notifyListeners();
  }

  Future<void> confirmReadAll() async {
    final before = _readAllBefore;
    if (_phase != NotificationPhase.readAllReview || before == null) return;
    final payload = <String, Object?>{'before': before.toIso8601String()};
    final existing = _protectedReadAll;
    if (existing != null && !existing.matchesPayload(payload)) {
      await _journal.clear(operation);
      _protectedReadAll = null;
      _phase = NotificationPhase.terminalFailure;
      _message = 'The saved read-all cutoff changed and cannot be reused.';
      notifyListeners();
      return;
    }
    _protectedReadAll = await _journal.protect(
      operation: operation,
      payload: payload,
      precondition: payload,
      reuse: existing,
    );
    _phase = NotificationPhase.mutating;
    _message = null;
    notifyListeners();
    try {
      await _repository.readAll(
        NotificationReadAll(
          before: before,
          idempotencyKey: _protectedReadAll!.key,
        ),
      );
      await _journal.clear(operation);
      _protectedReadAll = null;
      _readAllBefore = null;
      await _refreshAfterMutation();
    } on AmbiguousNotificationReadAll {
      await _reconcileReadAll(before);
    } on Object catch (error) {
      _mapFailure(error, preserveValue: true);
      if (_phase == NotificationPhase.forbidden ||
          _phase == NotificationPhase.terminalFailure) {
        await _journal.clear(operation);
        _protectedReadAll = null;
      }
    }
    notifyListeners();
  }

  Future<void> retryReconciliation() async {
    if (_phase != NotificationPhase.reconciliationRequired) return;
    final preferenceDraft = _preferenceRecoveryDraft;
    if (preferenceDraft != null) {
      await _reconcilePreferences(preferenceDraft);
      notifyListeners();
      return;
    }
    if (_protectedReadAll == null || _readAllBefore == null) return;
    await _reconcileReadAll(_readAllBefore!);
    notifyListeners();
  }

  Future<void> discardPendingReadAll() async {
    if (_protectedReadAll == null || _readAllBefore == null) return;
    final applied = await _readAllApplied(_readAllBefore!);
    if (applied == null) {
      _phase = NotificationPhase.reconciliationRequired;
      _message =
          'Fresh unread coverage is required before discarding recovery.';
    } else {
      await _journal.clear(operation);
      _protectedReadAll = null;
      _readAllBefore = null;
      await _refreshAfterMutation();
      _message = applied
          ? 'The server confirms the saved read-all command completed.'
          : 'Saved read-all recovery discarded after fresh authority and explicit review.';
    }
    notifyListeners();
  }

  Future<void> _restoreReadAll() async {
    final restored = await _journal.restore(operation);
    if (restored == null) return;
    try {
      if (restored.precondition.length != 1 ||
          restored.precondition['before'] is! String) {
        throw const FormatException();
      }
      final before = DateTime.parse(restored.precondition['before']! as String);
      if (!before.isUtc) throw const FormatException();
      _protectedReadAll = restored;
      _readAllBefore = before;
      await _reconcileReadAll(before);
    } on Object {
      await _journal.clear(operation);
      _protectedReadAll = null;
      _readAllBefore = null;
      _phase = NotificationPhase.terminalFailure;
      _message = 'The saved in-app read review is unsupported. Start again.';
    }
  }

  Future<void> _reconcileReadAll(DateTime before) async {
    final applied = await _readAllApplied(before);
    if (applied == true) {
      await _journal.clear(operation);
      _protectedReadAll = null;
      _readAllBefore = null;
      await _refreshAfterMutation();
      _message = 'The server confirms the saved in-app read command completed.';
    } else if (applied == false) {
      _phase = NotificationPhase.restoredReview;
      _message = 'Fresh authority still shows unread notices. Review before a same-key retry.';
    } else {
      _phase = NotificationPhase.reconciliationRequired;
      _message = 'Complete authoritative unread coverage is unavailable. Nothing will retry automatically.';
    }
  }

  Future<bool?> _readAllApplied(DateTime before) async {
    String? cursor;
    final cursors = <String>{};
    try {
      while (true) {
        final page = await _repository.load(
          filter: NotificationReadFilter.unread,
          cursor: cursor,
        );
        if (page.isStale) return null;
        for (final item in page.value.items) {
          final scheduledAt = item.scheduledAt;
          if (scheduledAt != null && !scheduledAt.isAfter(before)) return false;
        }
        if (!page.value.hasMore) return true;
        final next = page.value.nextCursor;
        if (next == null || next.isEmpty || !cursors.add(next)) return null;
        cursor = next;
      }
    } on Object {
      return null;
    }
  }

  Future<void> _reconcilePreferences(
    NotificationPreferencesDraft preserved,
  ) async {
    try {
      final result = await _repository.getPreferences();
      if (result.isStale) throw const OfflineException();
      _preferences = result.value;
      if (preserved.exactlyMatches(result.value)) {
        _preferenceRecoveryDraft = null;
        _preferenceDraft = result.value.asDraft();
        _phase = _items.isEmpty
            ? NotificationPhase.empty
            : NotificationPhase.ready;
        _message =
            'The server confirms the in-app preference change completed.';
      } else {
        _preferenceRecoveryDraft = null;
        _preferenceDraft = preserved;
        _phase = NotificationPhase.preferenceConflict;
        _message = 'Preferences changed elsewhere. Your edits are preserved for review.';
      }
    } on Object {
      _preferenceDraft = preserved;
      _preferenceRecoveryDraft = preserved;
      _phase = NotificationPhase.reconciliationRequired;
      _message =
          'Authoritative preferences are unavailable. No retry was submitted.';
    }
  }

  Future<void> _refreshAfterMutation() async {
    final page = await _repository.load(filter: NotificationReadFilter.all);
    _items = page.value.items;
    _nextCursor = page.value.nextCursor;
    _hasMore = page.value.hasMore;
    _isStale = page.isStale;
    _phase = page.isStale
        ? NotificationPhase.stale
        : _items.isEmpty
        ? NotificationPhase.empty
        : NotificationPhase.ready;
  }

  void _handleInvalidation(InvalidationEvent event) {
    if (event.resource != 'notifications') return;
    _isStale = true;
    if (_items.isNotEmpty) _phase = NotificationPhase.stale;
    _message = 'Refreshing the authoritative in-app feed.';
    notifyListeners();
    unawaited(load(preserveValue: true));
  }

  void _mapFailure(Object error, {bool preserveValue = false}) {
    final loadPhase = switch (error) {
      OfflineException() => LoadPhase.retryableFailure,
      LoadFailure(:final phase) => phase,
      _ => LoadPhase.terminalFailure,
    };
    if (preserveValue && _items.isNotEmpty) {
      _isStale = true;
      _phase = NotificationPhase.stale;
      _message =
          'Cached in-app notices remain visible; read state is uncertain.';
      return;
    }
    _phase = switch (loadPhase) {
      LoadPhase.forbidden => NotificationPhase.forbidden,
      LoadPhase.throttled => NotificationPhase.throttled,
      LoadPhase.retryableFailure => NotificationPhase.retryableFailure,
      LoadPhase.empty => NotificationPhase.empty,
      _ => NotificationPhase.terminalFailure,
    };
    _message = switch (_phase) {
      NotificationPhase.forbidden =>
        'This in-app feed is unavailable for this account.',
      NotificationPhase.throttled =>
        'The in-app feed is temporarily rate limited.',
      NotificationPhase.retryableFailure =>
        'The in-app feed is unavailable offline.',
      NotificationPhase.empty => 'No in-app notices are available.',
      _ => 'The notification response could not be safely understood.',
    };
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_invalidationSubscription.cancel());
    super.dispose();
  }
}
