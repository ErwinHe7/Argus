// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api/financial_command_journal.dart';
import '../../../core/api/pending_command_store.dart';
import '../../../core/bootstrap/member_bootstrap.dart';
import '../../../core/cache/read_cache.dart';
import '../data/repository.dart';
import '../domain/model.dart';

enum PrivacyPhase {
  idle,
  loading,
  empty,
  exportPending,
  downloadReady,
  downloading,
  shared,
  exportFailed,
  deletionReview,
  deletionAccepted,
  restoredReview,
  conflict,
  forbidden,
  throttled,
  retryableFailure,
  terminalFailure,
}

enum _PrivacyOperation { export, deletion }

class PrivacyController extends ChangeNotifier {
  PrivacyController({
    required PrivacyRepository repository,
    required PendingCommandStore pendingStore,
    required this.scope,
    required String Function() createKey,
    required Future<void> Function() reauthenticate,
    required Future<String> Function() authorizeDeletion,
    required Future<void> Function() onDeletionAccepted,
    MemberPersonalization personalization = const MemberPersonalization(),
  }) : _repository = repository,
       _reauthenticate = reauthenticate,
       _authorizeDeletion = authorizeDeletion,
       _onDeletionAccepted = onDeletionAccepted,
       _personalization = personalization,
       _journal = FinancialCommandJournal(
         store: pendingStore,
         scope: scope,
         createKey: createKey,
         now: DateTime.now,
       );

  final PrivacyRepository _repository;
  final FinancialCommandJournal _journal;
  final Future<void> Function() _reauthenticate;
  final Future<String> Function() _authorizeDeletion;
  Future<void> Function() _onDeletionAccepted;
  final CacheScope scope;
  MemberPersonalization _personalization;

  PrivacyPhase _phase = PrivacyPhase.idle;
  PrivacyExport? _export;
  PrivacyDeletionReceipt? _deletionReceipt;
  String? _knownExportRequestId;
  String? _message;
  JournaledFinancialCommand? _protectedCommand;
  _PrivacyOperation? _protectedOperation;
  bool _deactivated = false;
  bool _busy = false;

  PrivacyPhase get phase => _phase;
  PrivacyExport? get export => _export;
  PrivacyDeletionReceipt? get deletionReceipt => _deletionReceipt;
  String? get message => _message;
  bool get isBusy => _busy;
  bool get hasProtectedCommand => _protectedCommand != null;
  bool get hasProtectedExport =>
      _protectedOperation == _PrivacyOperation.export;
  bool get hasProtectedDeletion =>
      _protectedOperation == _PrivacyOperation.deletion;
  bool get canRefreshExport =>
      _knownExportRequestId != null &&
      !hasProtectedCommand &&
      switch (_phase) {
        PrivacyPhase.exportPending ||
        PrivacyPhase.downloadReady ||
        PrivacyPhase.forbidden ||
        PrivacyPhase.throttled ||
        PrivacyPhase.retryableFailure => true,
        _ => false,
      };
  String? get protectedActionLabel => switch (_protectedOperation) {
    _PrivacyOperation.export => 'Review saved export request',
    _PrivacyOperation.deletion => 'Review saved account deletion',
    null => null,
  };

  String get framingLabel {
    final voice = switch (_personalization.ritualVoice) {
      MemberRitualVoice.practical => 'Practical',
      MemberRitualVoice.mystical => 'Symbolic',
      MemberRitualVoice.balanced || MemberRitualVoice.unavailable => 'Balanced',
    };
    final depth = switch (_personalization.explanationDepth) {
      MemberExplanationDepth.beginner => 'step-by-step',
      MemberExplanationDepth.guided => 'guided',
      MemberExplanationDepth.advanced => 'concise',
      MemberExplanationDepth.unavailable => 'standard',
    };
    return '$voice · $depth explanation';
  }

  void bindAccountTransitions({
    required Future<void> Function() onDeletionAccepted,
  }) {
    _onDeletionAccepted = onDeletionAccepted;
  }

  void updatePersonalization(MemberPersonalization value) {
    if (_personalization.explanationDepth == value.explanationDepth &&
        _personalization.ritualVoice == value.ritualVoice) {
      return;
    }
    _personalization = value;
    notifyListeners();
  }

  Future<void> load() async {
    if (_deactivated || _busy) return;
    _busy = true;
    _phase = PrivacyPhase.loading;
    _message = null;
    notifyListeners();
    try {
      await _repository.clearStaleLocalFiles();
      if (_deactivated) return;
      await _restoreProtectedCommand();
      if (_deactivated) return;
      if (_protectedCommand != null) return;
      final requestId = await _repository.restoreExportId();
      if (_deactivated) return;
      if (requestId == null) {
        if (_protectedCommand == null) _phase = PrivacyPhase.empty;
        return;
      }
      _knownExportRequestId = requestId;
      await _refreshExport(requestId);
    } on Object catch (error) {
      if (!_deactivated) _setFailure(error);
    } finally {
      _busy = false;
      if (!_deactivated) notifyListeners();
    }
  }

  Future<void> requestExport() async {
    if (_deactivated || _busy) return;
    final payload = <String, Object?>{'format': 'zip'};
    final current = _commandFor(_PrivacyOperation.export);
    if (current != null && !current.matchesPayload(payload)) {
      await _clearProtected();
      if (_deactivated) return;
      _setTerminal('The saved export request changed and cannot be reused.');
      return;
    }
    _busy = true;
    _phase = PrivacyPhase.loading;
    _message = null;
    notifyListeners();
    try {
      final protected = await _journal.protect(
        operation: _operationName(_PrivacyOperation.export),
        payload: payload,
        precondition: payload,
        reuse: current,
      );
      if (_deactivated) {
        await _journal.clear(_operationName(_PrivacyOperation.export));
        return;
      }
      _protectedCommand = protected;
      _protectedOperation = _PrivacyOperation.export;
      final result = await _withRecentAuth(
        () => _repository.requestExport(_protectedCommand!.key),
      );
      if (_deactivated) return;
      _requireExport(result);
      await _repository.rememberExportId(result.id);
      if (_deactivated) {
        await _repository.forgetExportId(result.id);
        return;
      }
      _knownExportRequestId = result.id;
      await _clearProtected();
      if (_deactivated) return;
      _export = result;
      _setExportPhase(result);
    } on AmbiguousPrivacyMutation {
      if (!_deactivated) {
        _phase = PrivacyPhase.restoredReview;
        _message = 'The export response was interrupted. Review before retrying the unchanged request.';
      }
    } on Object catch (error) {
      if (!_deactivated) _setFailure(error);
    } finally {
      _busy = false;
      if (!_deactivated) notifyListeners();
    }
  }

  Future<void> refreshExport() async {
    if (_deactivated || _busy) return;
    final requestId =
        _knownExportRequestId ??
        _export?.id ??
        await _repository.restoreExportId();
    if (_deactivated) return;
    if (requestId == null) {
      _phase = PrivacyPhase.empty;
      notifyListeners();
      return;
    }
    _knownExportRequestId = requestId;
    _busy = true;
    _phase = PrivacyPhase.loading;
    notifyListeners();
    try {
      await _refreshExport(requestId);
    } on Object catch (error) {
      if (!_deactivated) _setFailure(error);
    } finally {
      _busy = false;
      if (!_deactivated) notifyListeners();
    }
  }

  Future<void> downloadAndShare() async {
    if (_deactivated || _busy) return;
    final requestId = _export?.id;
    if (requestId == null) return;
    _busy = true;
    _phase = PrivacyPhase.downloading;
    _message = null;
    notifyListeners();
    try {
      final latest = await _withRecentAuth(
        () => _repository.getExport(requestId),
      );
      if (_deactivated) return;
      _requireExport(latest, expectedId: requestId);
      _export = latest;
      if (!latest.canDownload) {
        _setExportPhase(latest);
        return;
      }
      final delivery = await _withRecentAuth(
        () => _repository.downloadAndShare(requestId),
      );
      if (_deactivated) return;
      if (delivery == PrivateExportDelivery.requested) {
        _phase = PrivacyPhase.downloadReady;
        _message = 'Download requested. Check your browser, then retry if it did not start.';
        return;
      }
      await _repository.forgetExportId(requestId);
      if (_deactivated) return;
      _knownExportRequestId = null;
      _phase = PrivacyPhase.shared;
      _message =
          'A private local copy was shared and removed from Ritual Investing.';
    } on Object catch (error) {
      if (!_deactivated) _setFailure(error);
    } finally {
      _busy = false;
      if (!_deactivated) notifyListeners();
    }
  }

  void prepareDeletion() {
    if (_deactivated || _busy || _phase == PrivacyPhase.deletionAccepted) {
      return;
    }
    _phase = PrivacyPhase.deletionReview;
    _message = 'Deletion signs you out immediately and cannot be reversed after acceptance.';
    notifyListeners();
  }

  void reviewRestoredAction() {
    if (_busy || _protectedOperation == null) {
      return;
    }
    switch (_protectedOperation!) {
      case _PrivacyOperation.export:
        _phase = PrivacyPhase.restoredReview;
        _message = 'Review retrying the unchanged export request with its protected command key.';
      case _PrivacyOperation.deletion:
        _phase = PrivacyPhase.deletionReview;
        _message = 'Review the irreversible deletion again. Nothing has been resubmitted.';
    }
    notifyListeners();
  }

  Future<void> confirmDeletion() async {
    if (_deactivated ||
        _busy ||
        _phase != PrivacyPhase.deletionReview &&
            !(_phase == PrivacyPhase.restoredReview &&
                _protectedOperation == _PrivacyOperation.deletion)) {
      return;
    }
    const payload = <String, Object?>{'confirmation': 'DELETE'};
    final current = _commandFor(_PrivacyOperation.deletion);
    _busy = true;
    _phase = PrivacyPhase.loading;
    notifyListeners();
    try {
      final protected = await _journal.protect(
        operation: _operationName(_PrivacyOperation.deletion),
        payload: payload,
        precondition: payload,
        reuse: current,
      );
      if (_deactivated) {
        await _journal.clear(_operationName(_PrivacyOperation.deletion));
        return;
      }
      _protectedCommand = protected;
      _protectedOperation = _PrivacyOperation.deletion;
      final stepUpReceipt = await _authorizeDeletion();
      if (_deactivated) return;
      final receipt = await _repository.requestDeletion(
        _protectedCommand!.key,
        stepUpReceipt,
      );
      if (_deactivated) return;
      _deletionReceipt = receipt;
      await _acceptDeletion();
    } on AccountInactive {
      if (!_deactivated) await _acceptDeletion();
    } on AmbiguousPrivacyMutation {
      try {
        final inactive = await _repository.accountInactive();
        if (_deactivated) return;
        if (inactive) {
          await _acceptDeletion();
        } else {
          _phase = PrivacyPhase.restoredReview;
          _message = 'Deletion authority is still active. Review before the same-key retry.';
        }
      } on Object catch (error) {
        if (!_deactivated) {
          _phase = PrivacyPhase.restoredReview;
          _message =
              'Deletion status is unavailable. Nothing retried automatically.';
          if (error is PrivacyFailure &&
              error.kind == PrivacyFailureKind.terminal) {
            _setFailure(error);
          }
        }
      }
    } on Object catch (error) {
      if (!_deactivated) _setFailure(error);
    } finally {
      _busy = false;
      if (!_deactivated) notifyListeners();
    }
  }

  Future<void> deactivate() async {
    _deactivated = true;
    await Future.wait([
      _repository.cancelAndClearLocal(),
      ..._PrivacyOperation.values.map(
        (operation) => _journal.clear(_operationName(operation)),
      ),
    ]);
    _protectedCommand = null;
    _protectedOperation = null;
    _export = null;
    _knownExportRequestId = null;
    _deletionReceipt = null;
    _message = null;
  }

  Future<T> _withRecentAuth<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on RecentAuthRequired {
      if (_deactivated) throw const PrivacyFailure(PrivacyFailureKind.terminal);
      await _reauthenticate();
      if (_deactivated) throw const PrivacyFailure(PrivacyFailureKind.terminal);
      return action();
    }
  }

  Future<void> _refreshExport(String requestId) async {
    final result = await _withRecentAuth(
      () => _repository.getExport(requestId),
    );
    if (_deactivated) return;
    _requireExport(result, expectedId: requestId);
    _export = result;
    _setExportPhase(result);
  }

  void _setExportPhase(PrivacyExport value) {
    _phase = switch (value.status) {
      PrivacyExportStatus.completed when value.hasDownloadGrant =>
        PrivacyPhase.downloadReady,
      PrivacyExportStatus.failed ||
      PrivacyExportStatus.cancelled => PrivacyPhase.exportFailed,
      _ => PrivacyPhase.exportPending,
    };
    _message = switch (_phase) {
      PrivacyPhase.downloadReady => 'Your private ZIP is ready. A fresh one-time link is used only during download.',
      PrivacyPhase.exportFailed =>
        'This export reached a terminal state. Start a new request when ready.',
      PrivacyPhase.exportPending
          when value.status == PrivacyExportStatus.completed =>
        'The export completed, but no fresh download is available. Refresh its status to request the latest one-time link.',
      _ => 'Your coherent Demo account archive is still being prepared.',
    };
  }

  Future<void> _acceptDeletion() async {
    await _clearProtected();
    if (_deactivated) return;
    _phase = PrivacyPhase.deletionAccepted;
    _message = 'Deletion was accepted. This device is signing out.';
    await _onDeletionAccepted();
  }

  Future<void> _restoreProtectedCommand() async {
    final restored = <(_PrivacyOperation, JournaledFinancialCommand)>[];
    for (final operation in _PrivacyOperation.values) {
      final command = await _journal.restore(_operationName(operation));
      if (_deactivated) return;
      if (command != null) restored.add((operation, command));
    }
    if (restored.isEmpty) return;
    if (restored.length != 1 || !_validRestored(restored.single)) {
      await Future.wait(
        _PrivacyOperation.values.map(
          (operation) => _journal.clear(_operationName(operation)),
        ),
      );
      if (_deactivated) return;
      _phase = PrivacyPhase.terminalFailure;
      _message = 'A saved privacy review is unsupported and was discarded.';
      return;
    }
    _protectedOperation = restored.single.$1;
    _protectedCommand = restored.single.$2;
    _phase = PrivacyPhase.restoredReview;
    _message = 'A protected privacy action was restored for review. Nothing submitted automatically.';
  }

  bool _validRestored((_PrivacyOperation, JournaledFinancialCommand) value) {
    final payload = value.$2.precondition;
    return switch (value.$1) {
      _PrivacyOperation.export =>
        payload.length == 1 && payload['format'] == 'zip',
      _PrivacyOperation.deletion =>
        payload.length == 1 && payload['confirmation'] == 'DELETE',
    };
  }

  JournaledFinancialCommand? _commandFor(_PrivacyOperation operation) =>
      _protectedOperation == operation ? _protectedCommand : null;

  Future<void> _clearProtected() async {
    final operation = _protectedOperation;
    if (operation != null) await _journal.clear(_operationName(operation));
    _protectedOperation = null;
    _protectedCommand = null;
  }

  void _setFailure(Object error) {
    final kind = switch (error) {
      PrivacyFailure(:final kind) => kind,
      RecentAuthRequired() ||
      RecentAuthCancelled() => PrivacyFailureKind.forbidden,
      _ => PrivacyFailureKind.terminal,
    };
    _phase = switch (kind) {
      PrivacyFailureKind.forbidden => PrivacyPhase.forbidden,
      PrivacyFailureKind.conflict => PrivacyPhase.conflict,
      PrivacyFailureKind.throttled => PrivacyPhase.throttled,
      PrivacyFailureKind.retryable => PrivacyPhase.retryableFailure,
      PrivacyFailureKind.terminal => PrivacyPhase.terminalFailure,
    };
    _message = switch ((kind, error)) {
      (PrivacyFailureKind.forbidden, RecentAuthCancelled()) => 'Recent authentication was cancelled. Nothing was submitted; review the saved action to continue.',
      (PrivacyFailureKind.forbidden, _) =>
        'Recent authentication or privacy permission is required.',
      (PrivacyFailureKind.conflict, _) =>
        'Another privacy request is already active. Refresh before continuing.',
      (PrivacyFailureKind.throttled, _) =>
        'Please wait before trying this privacy action again.',
      (PrivacyFailureKind.retryable, _) => 'Privacy authority is temporarily unavailable. Nothing retried automatically.',
      (PrivacyFailureKind.terminal, _) =>
        'This privacy response is not supported by this app version.',
    };
  }

  void _setTerminal(String message) {
    _phase = PrivacyPhase.terminalFailure;
    _message = message;
    notifyListeners();
  }

  void _requireExport(PrivacyExport value, {String? expectedId}) {
    if (!_uuid.hasMatch(value.id) ||
        expectedId != null && value.id != expectedId ||
        value.hasDownloadGrant &&
            value.status != PrivacyExportStatus.completed) {
      throw const PrivacyFailure(PrivacyFailureKind.terminal);
    }
  }

  @override
  void dispose() {
    if (!_deactivated) {
      _deactivated = true;
      unawaited(_repository.cancelAndClearLocal());
    }
    super.dispose();
  }
}

String _operationName(_PrivacyOperation value) => switch (value) {
  _PrivacyOperation.export => 'privacy.export',
  _PrivacyOperation.deletion => 'privacy.deletion',
};

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);
