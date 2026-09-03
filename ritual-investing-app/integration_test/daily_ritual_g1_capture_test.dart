import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/features/ritual/application/leonidas_voice.dart';
import 'package:ritual_investing_app/features/ritual/presentation/daily_ritual_screen.dart';
import 'package:ritual_investing_app/features/ritual/presentation/daily_ritual_stage_spec.dart';

import 'support/u4_http_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures the five G1 Daily Ritual states on iPhone', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

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

    var starpathOpened = false;
    await tester.pumpWidget(
      _CaptureApp(
        harness: harness,
        onOpenStarpath: () => starpathOpened = true,
        monotonicNow: () => Duration(
          microseconds: tester.binding.clock.now().microsecondsSinceEpoch,
        ),
      ),
    );
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

    tester.semantics.tap(find.semantics.byLabel('Begin ritual'));
    await tester.pump();
    await tester.runAsync(() => harness.ritualController.authorityIdle);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('3 of 5 seconds'), findsOneWidget);
    await _capture(binding, tester, '02-holding-60');

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.runAsync(() => harness.ritualController.authorityIdle);
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

    await tester.tap(find.byKey(DailyRitualStageSpec.evidenceKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ritual-evidence-sheet')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ritual-evidence-done')));
    await tester.pumpAndSettle();
    expect(find.byKey(DailyRitualStageSpec.evidenceKey), findsOneWidget);

    await tester.tap(find.byKey(DailyRitualStageSpec.starpathKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily-ritual-immersive')), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(starpathOpened, isTrue);
    semantics.dispose();
  });
}

class _CaptureApp extends StatelessWidget {
  const _CaptureApp({
    required this.harness,
    required this.onOpenStarpath,
    required this.monotonicNow,
  });

  final U4HttpHarness harness;
  final VoidCallback onOpenStarpath;
  final Duration Function() monotonicNow;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    home: Scaffold(
      body: DailyRitualScreen(
        controller: harness.ritualController,
        onOpenCoven: () {},
        onToggleTheme: () {},
        onOpenStarpath: onOpenStarpath,
        leonidasVoice: const _ImmediateLeonidasVoice(),
        monotonicNow: monotonicNow,
        prepareExactMedia: (_) async => true,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_awesome),
            label: 'Ritual',
          ),
          NavigationDestination(icon: Icon(Icons.stars), label: 'Starpath'),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.nights_stay_outlined),
            label: 'Coven',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            label: 'You',
          ),
        ],
      ),
    ),
  );
}

class _ImmediateLeonidasVoice implements LeonidasVoice {
  const _ImmediateLeonidasVoice();

  @override
  Future<bool> speak(String text) async => true;

  @override
  Future<void> stop() async {}
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
