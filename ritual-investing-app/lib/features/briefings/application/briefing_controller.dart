// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api/invalidation_bus.dart';
import '../../../core/api/view_state.dart';
import '../../../core/bootstrap/member_bootstrap.dart';
import '../../../core/cache/read_cache.dart';
import '../data/repository.dart';
import '../domain/model.dart';

enum BriefingPhase {
  idle,
  loading,
  empty,
  ready,
  stale,
  pending,
  detailReady,
  mutating,
  forbidden,
  throttled,
  retryableFailure,
  terminalFailure,
}

class BriefingController extends ChangeNotifier {
  BriefingController({
    required BriefingRepository repository,
    required InvalidationBus invalidationBus,
    required this.scope,
    MemberPersonalization personalization = const MemberPersonalization(),
  }) : _repository = repository,
       _personalization = personalization {
    _invalidationSubscription = invalidationBus
        .eventsFor(scope)
        .listen(_handleInvalidation);
  }

  final BriefingRepository _repository;
  final CacheScope scope;
  late final StreamSubscription<InvalidationEvent> _invalidationSubscription;
  BriefingPhase _phase = BriefingPhase.idle;
  List<BriefingSummary> _items = const [];
  BriefingDetail? _selected;
  DateTime? _pendingDate;
  String? _nextCursor;
  bool _hasMore = false;
  bool _isStale = false;
  String? _message;
  MemberPersonalization _personalization;
  bool _disposed = false;

  BriefingPhase get phase => _phase;
  List<BriefingSummary> get items => List.unmodifiable(_items);
  BriefingDetail? get selected => _selected;
  DateTime? get pendingDate => _pendingDate;
  bool get hasMore => _hasMore;
  bool get isStale => _isStale;
  String? get message => _message;

  String get framingLabel => switch (_personalization.ritualVoice) {
    MemberRitualVoice.practical =>
      'Practical reflection · reviewed display style',
    MemberRitualVoice.mystical =>
      'Symbolic reflection · reviewed display style',
    MemberRitualVoice.balanced || MemberRitualVoice.unavailable =>
      'Balanced reflection · reviewed display style',
  };

  void updatePersonalization(MemberPersonalization value) {
    if (_personalization.ritualVoice == value.ritualVoice) return;
    _personalization = value;
    notifyListeners();
  }

  Future<void> load({bool preserveValue = false}) async {
    if (!preserveValue) {
      _phase = BriefingPhase.loading;
      _message = null;
      notifyListeners();
    }
    try {
      final result = await _repository.load();
      _items = result.value.items;
      _nextCursor = result.value.nextCursor;
      _hasMore = result.value.hasMore;
      _isStale = result.isStale;
      _phase = result.isStale
          ? BriefingPhase.stale
          : _items.isEmpty
          ? BriefingPhase.empty
          : BriefingPhase.ready;
      _message = result.isStale
          ? 'Showing cached recaps. Read state and source sequence may have changed while offline.'
          : _items.isEmpty
          ? 'No current recaps are available yet. Nothing was generated on this device.'
          : null;
    } on Object catch (error) {
      _mapFailure(error, preserveValue: preserveValue || _items.isNotEmpty);
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    final cursor = _nextCursor;
    if (!_hasMore || cursor == null) return;
    try {
      final result = await _repository.load(cursor: cursor);
      final known = _items.map((item) => item.id).toSet();
      _items = [
        ..._items,
        ...result.value.items.where((item) => known.add(item.id)),
      ];
      _nextCursor = result.value.nextCursor;
      _hasMore = result.value.hasMore;
      _isStale = _isStale || result.isStale;
      _phase = _isStale ? BriefingPhase.stale : BriefingPhase.ready;
      if (_isStale) {
        _message =
            'Cached pagination is visible; read state remains uncertain.';
      }
    } on Object catch (error) {
      _mapFailure(error, preserveValue: true);
    }
    notifyListeners();
  }

  Future<void> open(String briefingId) async {
    _phase = BriefingPhase.loading;
    _message = null;
    notifyListeners();
    try {
      final result = await _repository.get(briefingId);
      if (result.value.id != briefingId) {
        throw const LoadFailure(LoadPhase.terminalFailure);
      }
      _selected = result.value;
      _isStale = result.isStale;
      _phase = result.isStale ? BriefingPhase.stale : BriefingPhase.detailReady;
      _message = result.isStale
          ? 'Showing a cached recap. Its read state and source sequence are not yet authoritative.'
          : null;
    } on Object catch (error) {
      _selected = null;
      _mapFailure(error);
    }
    notifyListeners();
  }

  Future<void> loadDaily(DateTime localDate) async {
    _phase = BriefingPhase.loading;
    _pendingDate = null;
    _message = null;
    notifyListeners();
    try {
      final result = await _repository.daily(localDate);
      if (result.isPending) {
        _pendingDate = result.pendingDate;
        _selected = null;
        _phase = BriefingPhase.pending;
        _message = 'Today’s recap is pending on the server. The app does not generate or poll for it.';
      } else {
        _selected = result.detail;
        _phase = BriefingPhase.detailReady;
      }
    } on Object catch (error) {
      _mapFailure(error);
    }
    notifyListeners();
  }

  Future<void> setSelectedRead(bool read) async {
    final current = _selected;
    if (current == null || _phase == BriefingPhase.mutating) return;
    _phase = BriefingPhase.mutating;
    _message = null;
    notifyListeners();
    try {
      final summary = await _repository.setRead(current.id, read);
      if (summary.id != current.id || summary.isRead != read) {
        throw const LoadFailure(LoadPhase.terminalFailure);
      }
      _selected = current.copyWithSummary(summary);
      _items = _items
          .map((item) => item.id == summary.id ? summary : item)
          .toList(growable: false);
      _phase = BriefingPhase.detailReady;
    } on Object catch (error) {
      _mapFailure(error, preserveValue: true);
    }
    notifyListeners();
  }

  void _handleInvalidation(InvalidationEvent event) {
    if (event.resource != InvalidationResource.ledger) return;
    _isStale = true;
    if (_items.isNotEmpty) _phase = BriefingPhase.stale;
    _message = 'Recorded simulation state changed. Refreshing recap source sequences without changing saved content.';
    notifyListeners();
    unawaited(_refreshInvalidated());
  }

  Future<void> _refreshInvalidated() async {
    final selectedId = _selected?.id;
    await load(preserveValue: true);
    if (selectedId == null) return;
    try {
      final result = await _repository.get(selectedId);
      if (result.value.id != selectedId || result.isStale) {
        throw const OfflineException();
      }
      _selected = result.value;
      _isStale = false;
      _phase = BriefingPhase.detailReady;
      _message = null;
    } on Object {
      _isStale = true;
      _phase = BriefingPhase.stale;
      _message = 'The recap list refreshed, but this open detail is still cached and explicitly stale.';
    }
    notifyListeners();
  }

  void _mapFailure(Object error, {bool preserveValue = false}) {
    final loadPhase = switch (error) {
      OfflineException() => LoadPhase.retryableFailure,
      LoadFailure(:final phase) => phase,
      _ => LoadPhase.terminalFailure,
    };
    if (preserveValue && (_items.isNotEmpty || _selected != null)) {
      _isStale = true;
      _phase = BriefingPhase.stale;
      _message = 'Authoritative recaps are unavailable. Cached content remains visible with uncertain read state.';
      return;
    }
    _phase = switch (loadPhase) {
      LoadPhase.forbidden => BriefingPhase.forbidden,
      LoadPhase.throttled => BriefingPhase.throttled,
      LoadPhase.retryableFailure => BriefingPhase.retryableFailure,
      LoadPhase.empty => BriefingPhase.empty,
      _ => BriefingPhase.terminalFailure,
    };
    _message = switch (_phase) {
      BriefingPhase.forbidden => 'This recap is unavailable for this account.',
      BriefingPhase.throttled =>
        'Recaps are temporarily rate limited. Try again shortly.',
      BriefingPhase.retryableFailure =>
        'Recaps are unavailable offline. Retry when connected.',
      BriefingPhase.empty => 'That recap is no longer available.',
      _ => 'The recap response could not be safely understood.',
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
