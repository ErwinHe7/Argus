import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'production composition contains Webull commands but no live simulation',
    () {
      final source = File(
        'lib/core/bootstrap/production_member_feature_scope_factory.dart',
      ).readAsStringSync();

      expect(source, contains('GeneratedBrokerageOrderApiService'));
      expect(source, contains('brokerageOrderController:'));
      expect(source, isNot(contains('GeneratedOrderApiService')));
      expect(source, isNot(contains('GeneratedRecurringPlanApiService')));
      expect(source, isNot(contains('GeneratedRebalanceApiService')));
      expect(source, isNot(contains('CachedFundingRepository')));
      expect(source, isNot(contains('GeneratedEntitlementService')));
      expect(source, contains('memberScenarioController:'));
    },
  );

  test('production routes retain brokerage and notifications without Demo authority', () {
    final source = File('lib/features/profile/you_routes.dart')
        .readAsStringSync();

    expect(source, contains('..._brokerageOrderRoutes(container)'));
    expect(source, contains("path: 'notifications'"));
    expect(source, contains("path: 'notification-preferences'"));
    expect(source, contains('..._memberScenarioRoutes(container)'));
    expect(source, isNot(contains("path: 'demo-reset'")));
    expect(source, isNot(contains("path: 'membership'")));
    expect(source, isNot(contains('_simulatedInvestingRoutes')));
  });

  test(
    'Rowan production boundary has no brokerage context or command tool',
    () {
      final rowan = File(
        'lib/features/rowan/data/generated_rowan_api_service.dart',
      ).readAsStringSync();
      final factory = File(
        'lib/core/bootstrap/production_member_feature_scope_factory.dart',
      ).readAsStringSync();

      for (final forbidden in [
        'BrokerageOrder',
        'BrokerageBalance',
        'BrokeragePosition',
        'providerPayload',
        'credential',
        'commandTool',
      ]) {
        expect(rowan, isNot(contains(forbidden)));
      }
      expect(factory, isNot(contains('rowanController: brokerage')));
    },
  );
}
