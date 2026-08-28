import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/features/brokerage_connection/data/generated_brokerage_connection_api_service.dart';
import 'package:ritual_investing_app/features/brokerage_connection/domain/model.dart';

void main() {
  test(
    'strict adapter maps generated account authority and active selection',
    () {
      final snapshot = mapBrokerageConnectionSnapshot(
        WebullConnection(
          id: 'connection-a',
          status: WebullConnectionStatusEnum.connected,
        ),
        [_account('account-a', selected: true)],
      );

      expect(snapshot.phase, BrokerageConnectionPhase.connected);
      expect(snapshot.activeAccountId, 'account-a');
      expect(
        snapshot.accounts.single.capabilities.single.kind,
        BrokerageCapabilityKind.manualOrders,
      );
      expect(
        snapshot.lastAuthoritativeObservation,
        DateTime.utc(2026, 8, 28, 12),
      );
    },
  );

  test('unknown provider lifecycle and asset authority fail closed', () {
    final snapshot = mapBrokerageConnectionSnapshot(
      WebullConnection(
        status: WebullConnectionStatusEnum.unknownDefaultOpenApi,
      ),
      [
        _account(
          'account-a',
          selected: false,
          state: BrokerageAccountStateEnum.unknownDefaultOpenApi,
          capability: BrokerageCapabilityCapabilityEnum.unknownDefaultOpenApi,
        ),
      ],
    );

    expect(snapshot.phase, BrokerageConnectionPhase.unknown);
    expect(
      snapshot.accounts.single.resourceState,
      BrokerageResourceState.unknown,
    );
    expect(
      snapshot.accounts.single.capabilities.single.kind,
      BrokerageCapabilityKind.unknown,
    );
  });

  test(
    'multiple selected accounts are rejected as a terminal contract error',
    () {
      expect(
        () => mapBrokerageConnectionSnapshot(
          WebullConnection(status: WebullConnectionStatusEnum.connected),
          [
            _account('account-a', selected: true),
            _account('account-b', selected: true),
          ],
        ),
        throwsA(
          isA<LoadFailure>().having(
            (failure) => failure.phase,
            'phase',
            LoadPhase.terminalFailure,
          ),
        ),
      );
    },
  );
}

BrokerageAccount _account(
  String id, {
  required bool selected,
  BrokerageAccountStateEnum state = BrokerageAccountStateEnum.fresh,
  BrokerageCapabilityCapabilityEnum capability =
      BrokerageCapabilityCapabilityEnum.manualOrders,
}) => BrokerageAccount(
  baseCurrency: 'USD',
  capabilities: [
    BrokerageCapability(
      available: true,
      capability: capability,
      providerCode: capability.value,
    ),
  ],
  capabilityVersion: 3,
  connectionId: 'connection-a',
  displayLabel: 'Synthetic $id',
  expiresAt: DateTime.utc(2026, 8, 28, 12, 1),
  fetchedAt: DateTime.utc(2026, 8, 28, 12),
  id: id,
  marketTimezone: 'America/New_York',
  providerObservedAt: DateTime.utc(2026, 8, 28, 12),
  selected: selected,
  state: state,
  status: BrokerageAccountStatusEnum.available,
);
