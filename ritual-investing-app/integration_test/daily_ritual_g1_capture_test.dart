import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ritual_investing_app/app/ritual_investing_app.dart';
import 'package:ritual_investing_app/features/ritual/presentation/daily_ritual_stage_spec.dart';

import '../test/support/fixture_services.dart';
import 'support/u4_http_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures the five G1 Daily Ritual states on iPhone', (
    tester,
  ) async {
    late U4HttpHarness harness;
    await tester.runAsync(() async {
      harness = await U4HttpHarness.start();
      await harness.ritualController.load();
    });
    addTearDown(() => harness.close(disposeRitualController: false));
    expect(
      harness.ritualController.state.value,
      isNotNull,
      reason:
          'Fixture authority must load before capture; phase was '
          '${harness.ritualController.state.phase.name}.',
    );

    await tester.pumpWidget(
      RitualInvestingApp(
        container: fixtureContainer(
          dailyRitualController: harness.ritualController,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await tester.runAsync(harness.ritualController.load);
    await tester.pumpAndSettle();

    expect(
      harness.ritualController.state.value,
      isNotNull,
      reason:
          'Fixture authority must remain available after shell bootstrap; '
          'phase was ${harness.ritualController.state.phase.name}.',
    );

    final start = find.byKey(const Key('leonidas-sequence-start'));
    expect(start, findsOneWidget);
    await _capture(binding, tester, '01-resting');

    await tester.tap(start);
    await tester.pump(DailyRitualStageSpec.startTransition);

    final hold = await tester.startGesture(
      tester.getCenter(find.byKey(DailyRitualStageSpec.sealHitKey)),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('3 of 5 seconds'), findsOneWidget);
    await _capture(binding, tester, '02-holding-60');

    await tester.pump(const Duration(seconds: 2, milliseconds: 1));
    await tester.pump();
    await hold.up();
    await tester.pumpAndSettle();

    expect(find.text('Reading revealed'), findsOneWidget);
    expect(find.byKey(DailyRitualStageSpec.cardArtKey), findsOneWidget);
    await _capture(binding, tester, '03-revealed');

    final voice = find.byKey(const Key('leonidas-voice-toggle'));
    expect(find.text('Voice on'), findsOneWidget);
    await tester.tap(voice);
    await tester.pump();
    expect(find.text('Voice off'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ritual-complete')));
    await tester.pump();
    await tester.pump(DailyRitualStageSpec.c2Expand);

    expect(find.text('Today’s ritual is complete.'), findsOneWidget);
    expect(find.byKey(const Key('leonidas-closing-skip')), findsOneWidget);
    await _capture(binding, tester, '04-c2-closing');

    await tester.tap(find.byKey(const Key('leonidas-closing-skip')));
    await tester.pump();
    await tester.pump(DailyRitualStageSpec.c2Settle);

    expect(find.byKey(DailyRitualStageSpec.evidenceKey), findsOneWidget);
    expect(find.byKey(DailyRitualStageSpec.starpathKey), findsOneWidget);
    await _capture(binding, tester, '05-completed-onward');
  });
}

Future<void> _capture(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
  final bytes = await binding.takeScreenshot(name);
  expect(bytes, isNotEmpty);
}
