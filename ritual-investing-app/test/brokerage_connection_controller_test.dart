import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/features/brokerage_connection/application/controller.dart';
import 'package:ritual_investing_app/features/brokerage_connection/data/repository.dart';
import 'package:ritual_investing_app/features/brokerage_connection/domain/model.dart';

void main() {
  test(
    'disconnected member can start Webull without blocking other surfaces',
    () async {
      final service = _ConnectionService();
      final opened = <Uri>[];
      final controller = BrokerageConnectionController(
        repository: BrokerageConnectionRepository(service: service),
        openAuthorization: (uri) async {
          opened.add(uri);
          return true;
        },
      );

      await controller.connect();

      expect(opened.single, Uri.https('sandbox.webull.test', '/authorize'));
      expect(controller.snapshot.phase, BrokerageConnectionPhase.pending);
      expect(controller.message, contains('secure Webull browser'));
    },
  );

  test(
    'account switch clears old account UI before selection completes',
    () async {
      final service = _ConnectionService()..snapshot = _connected('account-a');
      final selection = Completer<void>();
      service.selection = selection;
      var clears = 0;
      final controller = BrokerageConnectionController(
        repository: BrokerageConnectionRepository(service: service),
        openAuthorization: (_) async => true,
        initial: service.snapshot,
        onAccountChanging: () async => clears += 1,
      );

      final operation = controller.selectAccount('account-b');
      await Future<void>.delayed(Duration.zero);

      expect(clears, 1);
      expect(controller.snapshot.activeAccountId, isNull);

      service.snapshot = _connected('account-b');
      selection.complete();
      await operation;

      expect(controller.snapshot.activeAccountId, 'account-b');
    },
  );

  test(
    'completion handle is validated, redeemed once, and not exposed',
    () async {
      final service = _ConnectionService();
      final controller = BrokerageConnectionController(
        repository: BrokerageConnectionRepository(service: service),
        openAuthorization: (_) async => true,
      );

      await controller.handleCompletion('too-short');
      expect(service.completions, isEmpty);

      const completion = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQ';
      service.snapshot = _connected('account-a');
      await controller.handleCompletion(completion);

      expect(service.completions, [completion]);
      expect(controller.snapshot.phase, BrokerageConnectionPhase.connected);
      expect(controller.message, isNot(contains(completion)));
    },
  );

  test('reauthorization remains read-only and launches reconnect', () async {
    final service = _ConnectionService()
      ..snapshot = const BrokerageConnectionSnapshot(
        phase: BrokerageConnectionPhase.reauthorizationRequired,
        accounts: [],
      );
    var opened = 0;
    final controller = BrokerageConnectionController(
      repository: BrokerageConnectionRepository(service: service),
      openAuthorization: (_) async {
        opened += 1;
        return true;
      },
      initial: service.snapshot,
    );

    await controller.reconnect();

    expect(service.reconnects, 1);
    expect(opened, 1);
    expect(controller.snapshot.phase, BrokerageConnectionPhase.pending);
  });
}

class _ConnectionService implements BrokerageConnectionService {
  BrokerageConnectionSnapshot snapshot =
      const BrokerageConnectionSnapshot.disconnected();
  Completer<void>? selection;
  final List<String> completions = [];
  int reconnects = 0;

  @override
  Future<BrokerageConnectionSnapshot> fetch() async => snapshot;

  @override
  Future<BrokerageAuthorizationSession> start() async => _authorizationSession;

  @override
  Future<BrokerageAuthorizationSession> reconnect() async {
    reconnects += 1;
    return _authorizationSession;
  }

  @override
  Future<void> redeemCompletion(String completion) async {
    completions.add(completion);
  }

  @override
  Future<void> selectAccount(String accountId) async {
    await selection?.future;
  }
}

final _authorizationSession = BrokerageAuthorizationSession(
  authorizationUri: Uri.https('sandbox.webull.test', '/authorize'),
  expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
);

BrokerageConnectionSnapshot _connected(String selected) =>
    BrokerageConnectionSnapshot(
      phase: BrokerageConnectionPhase.connected,
      connectionId: 'connection-a',
      activeAccountId: selected,
      accounts: [
        _account('account-a', selected == 'account-a'),
        _account('account-b', selected == 'account-b'),
      ],
    );

BrokerageAccountView _account(String id, bool selected) => BrokerageAccountView(
  id: id,
  connectionId: 'connection-a',
  displayLabel: id,
  baseCurrency: 'USD',
  availability: BrokerageAccountAvailability.available,
  resourceState: BrokerageResourceState.fresh,
  capabilityVersion: 1,
  capabilities: const [],
  selected: selected,
);
