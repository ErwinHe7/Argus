import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/presentation/demo_disclosure.dart';
import 'package:ritual_investing_app/core/presentation/minor_money.dart';
import 'package:ritual_investing_app/core/presentation/server_time.dart';

void main() {
  test('minor money keeps integer precision and sign', () {
    expect(MinorMoney.usd(123456), r'$1,234.56');
    expect(MinorMoney.usd(-5), r'-$0.05');
  });

  test('server timestamps are explicit UTC rather than device-local', () {
    expect(
      ServerTime.timestamp(DateTime.parse('2026-08-24T12:05:30-04:00')),
      '2026-08-24 16:05 UTC',
    );
  });

  testWidgets('shared Demo badge has a non-color semantic label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: DemoBadge()),
      ),
    );

    expect(find.text('DEMO'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Demo experience; no real money moves'),
      findsOneWidget,
    );
    expect(
      DemoDisclosureCopy.marketScenario,
      'Demo market scenario · educational exploration only',
    );
  });
}
