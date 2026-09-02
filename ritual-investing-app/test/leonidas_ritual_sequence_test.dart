import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/features/ritual/domain/daily_ritual.dart';
import 'package:ritual_investing_app/features/ritual/presentation/leonidas_ritual_sequence.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets(
    'starts standing then moves close only after one successful reveal',
    (tester) async {
      _setPhoneViewport(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(
            accessibleNavigation: true,
            disableAnimations: true,
          );
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      final voice = _TrackingVoice();
      final reveal = Completer<bool>();
      var revealCount = 0;
      var evidenceCount = 0;

      await tester.pumpWidget(
        _testApp(
          ritual: _ritual(DailyRitualState.assigned),
          voice: voice,
          onReveal: () async {
            revealCount += 1;
            return reveal.future;
          },
          onShowEvidence: () => evidenceCount += 1,
        ),
      );

      expect(find.byKey(const Key('leonidas-card-back')), findsOneWidget);
      expect(find.byKey(const Key('leonidas-standing')), findsOneWidget);
      expect(find.byKey(const Key('leonidas-close-up')), findsNothing);

      await tester.tap(find.byKey(const Key('leonidas-sequence-start')));
      await tester.pump();

      expect(find.byKey(const Key('leonidas-standing')), findsOneWidget);
      expect(find.byKey(const Key('leonidas-close-up')), findsNothing);
      expect(
        find.text(
          'Come closer. We will let the card speak before we ask the evidence to agree.',
        ),
        findsOneWidget,
      );
      expect(revealCount, 0);
      expect(voice.lines, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));

      expect(revealCount, 1);
      expect(find.byKey(const Key('leonidas-card-back')), findsOneWidget);
      expect(find.byKey(const Key('leonidas-close-up')), findsNothing);

      reveal.complete(true);
      await tester.pumpAndSettle();

      expect(revealCount, 1);
      expect(find.byKey(const Key('leonidas-card-front')), findsOneWidget);
      expect(find.byKey(const Key('leonidas-close-up')), findsOneWidget);
      expect(find.byKey(const Key('leonidas-standing')), findsNothing);
      expect(find.text('Strength'), findsOneWidget);
      expect(find.byKey(const Key('leonidas-evidence')), findsOneWidget);
      expect(voice.lines, hasLength(1));
      expect(
        voice.lines.single,
        'Strength Patience is the stronger path. '
        'The choice remains yours. Demo counsel; not investment advice.',
      );

      await tester.tap(find.byKey(const Key('leonidas-evidence')));
      expect(evidenceCount, 1);
    },
  );

  testWidgets('failed reveal keeps the card concealed and captions usable', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
          accessibleNavigation: true,
          disableAnimations: true,
        );
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    final voice = _UnavailableVoice();
    await tester.pumpWidget(
      _testApp(
        ritual: _ritual(DailyRitualState.assigned),
        voice: voice,
        onReveal: () async => false,
      ),
    );

    await tester.tap(find.byKey(const Key('leonidas-sequence-start')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('leonidas-card-back')), findsOneWidget);
    expect(find.byKey(const Key('leonidas-card-front')), findsNothing);
    expect(find.byKey(const Key('leonidas-close-up')), findsNothing);
    expect(
      find.text(
        'The card could not be revealed. Your ritual remains safely concealed; try again when you are ready.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('leonidas-sequence-start')), findsOneWidget);
  });

  testWidgets('unexpected reveal errors fail closed and remain retryable', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
          accessibleNavigation: true,
          disableAnimations: true,
        );
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(
      _testApp(
        ritual: _ritual(DailyRitualState.assigned),
        voice: _UnavailableVoice(),
        onReveal: () => Future<bool>.error(StateError('transport ambiguity')),
      ),
    );

    await tester.tap(find.byKey(const Key('leonidas-sequence-start')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('leonidas-card-back')), findsOneWidget);
    expect(find.byKey(const Key('leonidas-close-up')), findsNothing);
    expect(find.byKey(const Key('leonidas-sequence-start')), findsOneWidget);
    expect(find.textContaining('remains safely concealed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an already revealed ritual opens on the close-up without speech',
    (tester) async {
      _setPhoneViewport(tester);
      final voice = _UnavailableVoice();
      await tester.pumpWidget(
        _testApp(
          ritual: _ritual(DailyRitualState.completed),
          voice: voice,
          onReveal: () async => true,
        ),
      );

      expect(find.byKey(const Key('leonidas-card-front')), findsOneWidget);
      expect(find.byKey(const Key('leonidas-close-up')), findsOneWidget);
      expect(find.byKey(const Key('leonidas-sequence-replay')), findsOneWidget);
      expect(voice.lines, isEmpty);
    },
  );

  testWidgets('voice can be disabled and the captions complete the ritual', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
          accessibleNavigation: true,
          disableAnimations: true,
        );
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    final voice = _TrackingVoice();
    var revealCount = 0;
    await tester.pumpWidget(
      _testApp(
        ritual: _ritual(DailyRitualState.assigned),
        voice: voice,
        onReveal: () async {
          revealCount += 1;
          return true;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('leonidas-voice-toggle')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('leonidas-sequence-start')));
    await tester.pumpAndSettle();

    expect(revealCount, 1);
    expect(voice.lines, isEmpty);
    expect(voice.stopCount, 1);
    expect(find.byKey(const Key('leonidas-sequence-replay')), findsOneWidget);
    expect(find.textContaining('The choice remains yours.'), findsOneWidget);
  });

  testWidgets('a stalled native voice falls back to complete captions', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
          accessibleNavigation: true,
          disableAnimations: true,
        );
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    final voice = _HangingVoice();
    var revealCount = 0;
    await tester.pumpWidget(
      _testApp(
        ritual: _ritual(DailyRitualState.assigned),
        voice: voice,
        onReveal: () async {
          revealCount += 1;
          return true;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('leonidas-sequence-start')));
    await tester.pump(const Duration(milliseconds: 4));
    await tester.pump(const Duration(minutes: 2));
    await tester.pumpAndSettle();

    expect(revealCount, 1);
    expect(voice.lines, hasLength(1));
    expect(voice.stopCount, 1);
    expect(find.byKey(const Key('leonidas-sequence-replay')), findsOneWidget);
  });

  testWidgets('long reviewed captions remain visible at 2x text', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final longInterpretation = List.filled(
      12,
      'A patient investor reads the full evidence before choosing what to research.',
    ).join(' ');
    final longCounsel = List.filled(
      8,
      'Hold confidence and uncertainty together without rushing the decision.',
    ).join(' ');

    await tester.pumpWidget(
      _testApp(
        ritual: _ritual(
          DailyRitualState.completed,
          interpretation: longInterpretation,
          counsel: longCounsel,
        ),
        voice: _UnavailableVoice(),
        onReveal: () async => true,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(longInterpretation), findsOneWidget);
    expect(find.textContaining(longCounsel), findsOneWidget);
    expect(find.byKey(const Key('leonidas-sequence-replay')), findsOneWidget);
  });
}

void _setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _testApp({
  required DailyRitual ritual,
  required LeonidasVoice voice,
  required Future<bool> Function() onReveal,
  VoidCallback? onShowEvidence,
}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: SingleChildScrollView(
        child: LeonidasRitualSequence(
          ritual: ritual,
          voice: voice,
          onReveal: onReveal,
          onShowEvidence: onShowEvidence,
        ),
      ),
    ),
  );
}

class _TrackingVoice implements LeonidasVoice {
  final List<String> lines = [];
  int stopCount = 0;

  @override
  Future<bool> speak(String text) async {
    lines.add(text);
    return true;
  }

  @override
  Future<void> stop() async => stopCount += 1;
}

class _HangingVoice implements LeonidasVoice {
  final List<String> lines = [];
  int stopCount = 0;

  @override
  Future<bool> speak(String text) {
    lines.add(text);
    return Completer<bool>().future;
  }

  @override
  Future<void> stop() async => stopCount += 1;
}

class _UnavailableVoice implements LeonidasVoice {
  final List<String> lines = [];

  @override
  Future<bool> speak(String text) async {
    lines.add(text);
    return false;
  }

  @override
  Future<void> stop() async {}
}

DailyRitual _ritual(
  DailyRitualState state, {
  String interpretation = 'Patience is the stronger path.',
  String counsel = 'The choice remains yours.',
}) => DailyRitual(
  assignmentId: '00000000-0000-4000-8000-000000000101',
  date: DateTime.utc(2026, 9, 2),
  mode: DailyRitualMode.tarot,
  revision: const RitualRevision(
    id: '00000000-0000-4000-8000-000000000102',
    number: 1,
  ),
  title: 'Strength',
  art: const RitualArt(
    key: 'strength',
    alt: 'Strength tarot card: a calm woman gently holds a golden lion',
  ),
  interpretation: interpretation,
  guidance: 'Inspect the evidence before choosing what deserves more research.',
  marketLabel: 'Market-informed · Demo scenario',
  ideas: const [],
  evidence: [
    RitualEvidence(
      claimId: '00000000-0000-4000-8000-000000000103',
      factorLabel: 'Durability',
      observedAt: DateTime.utc(2026, 9, 2, 12),
      summary: 'Margins improved in the fictional scenario.',
      uncertainty: 'Demand persistence is not established.',
    ),
  ],
  rowan: RitualCounsel(
    scriptRevisionId: '00000000-0000-4000-8000-000000000104',
    surface: 'daily_ritual',
    body: counsel,
    riskFooter: 'Demo counsel; not investment advice.',
  ),
  version: 1,
  state: state,
  revealedAt: state == DailyRitualState.assigned
      ? null
      : DateTime.utc(2026, 9, 2, 12, 1),
  completedAt: state == DailyRitualState.completed
      ? DateTime.utc(2026, 9, 2, 12, 2)
      : null,
  demo: RitualDisclosure(
    isDemo: true,
    observedAt: DateTime.utc(2026, 9, 2, 12),
    sourceLabel: 'Deterministic fixture',
    limitations: const ['Fictional scenario; no live provider data.'],
  ),
);
