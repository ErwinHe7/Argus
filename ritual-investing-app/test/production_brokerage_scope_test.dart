import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production scope keeps Webull and scenario-only feature wiring', () {
    final source = File(
      'lib/core/bootstrap/production_member_feature_scope_factory.dart',
    ).readAsStringSync();

    expect(source, contains('brokerageConnectionController:'));
    expect(source, contains('brokeragePortfolioController:'));
    expect(source, contains('brokerageOrderController:'));
    expect(source, isNot(contains('GeneratedOrderApiService')));
    expect(source, isNot(contains('GeneratedRecurringPlanApiService')));
    expect(source, isNot(contains('GeneratedRebalanceApiService')));
    expect(source, contains('memberScenarioController:'));
    expect(source, isNot(contains('intentionController:')));
    expect(source, isNot(contains('futureMirrorController:')));
  });
}
