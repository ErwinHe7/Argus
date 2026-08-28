// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../../core/api/view_state.dart';
import '../data/brokerage_repository.dart';
import '../domain/brokerage_model.dart';

class BrokeragePortfolioController extends ChangeNotifier {
  BrokeragePortfolioController({
    required BrokeragePortfolioRepository repository,
    String? initialAccountId,
  }) : _repository = repository,
       _accountId = initialAccountId;

  final BrokeragePortfolioRepository _repository;
  String? _accountId;
  String? get accountId => _accountId;
  ViewState<BrokeragePortfolioSnapshot> _state = const ViewState(
    phase: LoadPhase.idle,
  );
  ViewState<BrokeragePortfolioSnapshot> get state => _state;
  String? _message;
  String? get message => _message;
  Future<void>? _operation;

  Future<void> open(String accountId) async {
    if (_accountId != accountId) clear(accountId: accountId);
    await _load(refresh: false);
  }

  Future<void> refresh() => _load(refresh: true);

  void clear({String? accountId}) {
    _accountId = accountId;
    _state = const ViewState(phase: LoadPhase.idle);
    _message = null;
    notifyListeners();
  }

  Future<void> _load({required bool refresh}) {
    final active = _operation;
    if (active != null) return active;
    final accountId = _accountId;
    if (accountId == null) return Future.value();
    late final Future<void> operation;
    operation =
        () async {
          final prior = _state.value;
          _state = ViewState(
            phase: prior == null ? LoadPhase.loading : LoadPhase.stale,
            value: prior,
            committedAt: _state.committedAt,
          );
          notifyListeners();
          try {
            final snapshot = await _repository.load(
              accountId,
              refresh: refresh,
            );
            if (_accountId != accountId) return;
            _state = ViewState(
              phase: LoadPhase.ready,
              value: snapshot,
              committedAt: DateTime.now().toUtc(),
            );
            _message = null;
          } on Object {
            if (_accountId != accountId) return;
            _state = ViewState(
              phase: LoadPhase.retryableFailure,
              value: prior,
              committedAt: _state.committedAt,
            );
            _message = prior == null
                ? 'Webull account data is temporarily unavailable.'
                : 'Refresh failed. Timestamped Webull values may be stale.';
          } finally {
            notifyListeners();
          }
        }().whenComplete(() {
          if (identical(_operation, operation)) _operation = null;
        });
    _operation = operation;
    return operation;
  }
}
