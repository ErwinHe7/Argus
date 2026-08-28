// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../../core/api/view_state.dart';
import '../data/repository.dart';
import '../domain/model.dart';

typedef OpenBrokerageAuthorization = Future<bool> Function(Uri uri);

class BrokerageConnectionController extends ChangeNotifier {
  BrokerageConnectionController({
    required BrokerageConnectionRepository repository,
    required OpenBrokerageAuthorization openAuthorization,
    BrokerageConnectionSnapshot initial =
        const BrokerageConnectionSnapshot.disconnected(),
    Future<void> Function()? onAccountChanging,
  }) : _repository = repository,
       _openAuthorization = openAuthorization,
       _snapshot = initial,
       _onAccountChanging = onAccountChanging;

  final BrokerageConnectionRepository _repository;
  final OpenBrokerageAuthorization _openAuthorization;
  final Future<void> Function()? _onAccountChanging;

  BrokerageConnectionSnapshot _snapshot;
  BrokerageConnectionSnapshot get snapshot => _snapshot;
  LoadPhase _phase = LoadPhase.idle;
  LoadPhase get phase => _phase;
  String? _message;
  String? get message => _message;
  bool _busy = false;
  bool get isBusy => _busy;

  void updateBootstrap(BrokerageConnectionSnapshot snapshot) {
    if (identical(snapshot, _snapshot)) return;
    _snapshot = snapshot;
    _phase = LoadPhase.ready;
    _message = null;
    notifyListeners();
  }

  Future<void> load() => _run(() async {
    _snapshot = await _repository.load();
    _phase = LoadPhase.ready;
    _message = null;
  });

  Future<void> connect() => _authorize(reconnect: false);
  Future<void> reconnect() => _authorize(reconnect: true);

  Future<void> _authorize({required bool reconnect}) => _run(() async {
    final session = reconnect
        ? await _repository.reconnect()
        : await _repository.start();
    if (session.expiresAt.isBefore(DateTime.now().toUtc()) ||
        !await _openAuthorization(session.authorizationUri)) {
      _message = 'Webull authorization was not opened. You can safely retry.';
      return;
    }
    _snapshot = BrokerageConnectionSnapshot(
      phase: BrokerageConnectionPhase.pending,
      accounts: _snapshot.accounts,
      connectionId: _snapshot.connectionId,
      activeAccountId: _snapshot.activeAccountId,
      lastAuthoritativeObservation: _snapshot.lastAuthoritativeObservation,
    );
    _phase = LoadPhase.ready;
    _message = 'Finish authorization in the secure Webull browser.';
  });

  Future<void> handleCompletion(String completion) => _run(() async {
    if (!RegExp(r'^[A-Za-z0-9_-]{43,128}$').hasMatch(completion)) {
      _message = 'This Webull completion link is invalid or expired.';
      return;
    }
    await _repository.redeemCompletion(completion);
    _snapshot = await _repository.load();
    _phase = LoadPhase.ready;
    _message = switch (_snapshot.phase) {
      BrokerageConnectionPhase.connected => 'Webull connection updated.',
      BrokerageConnectionPhase.denied =>
        'Webull authorization was cancelled or denied.',
      BrokerageConnectionPhase.reauthorizationRequired =>
        'Webull needs authorization again.',
      _ => 'Webull connection status refreshed.',
    };
  });

  Future<void> selectAccount(String accountId) => _run(() async {
    final account = _snapshot.accounts
        .where((candidate) => candidate.id == accountId)
        .firstOrNull;
    if (account == null || !account.isSelectable) {
      _message = 'That Webull account is not available.';
      return;
    }
    if (accountId == _snapshot.activeAccountId) return;
    await _onAccountChanging?.call();
    _snapshot = BrokerageConnectionSnapshot(
      phase: _snapshot.phase,
      accounts: _snapshot.accounts,
      connectionId: _snapshot.connectionId,
      activeAccountId: null,
      lastAuthoritativeObservation: _snapshot.lastAuthoritativeObservation,
    );
    notifyListeners();
    await _repository.selectAccount(accountId);
    _snapshot = await _repository.load();
    if (_snapshot.activeAccountId != accountId) {
      throw StateError('The selected Webull account was not confirmed.');
    }
    _phase = LoadPhase.ready;
    _message = null;
  });

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    _phase = _snapshot.accounts.isEmpty ? LoadPhase.loading : LoadPhase.stale;
    notifyListeners();
    try {
      await action();
    } on Object {
      _phase = LoadPhase.retryableFailure;
      _message =
          'Webull is temporarily unavailable. Existing data was not changed.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
