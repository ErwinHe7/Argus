import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/features/ritual/domain/daily_ritual.dart';
import 'package:ritual_investing_app/features/ritual/presentation/daily_ritual_stage_spec.dart';
import 'package:ritual_investing_app/features/ritual/presentation/leonidas_ritual_sequence.dart';

void main() {
  testWidgets('resting stage matches the measured seal and Start geometry', (
    tester,
  ) async {
    _setReferenceViewport(tester);
    await tester.pumpWidget(
      _stageApp(ritual: _ritual(DailyRitualState.assigned)),
    );
    await tester.pump();
    await _decodeExactArt(tester);

    final stage = tester.getRect(find.byKey(DailyRitualStageSpec.stageKey));
    _expectRect(stage, DailyRitualStageSpec.stageViewport);
    _expectLocalRect(
      tester,
      DailyRitualStageSpec.portraitKey,
      stage,
      DailyRitualStageSpec.portrait,
    );
    _expectLocalRect(
      tester,
      DailyRitualStageSpec.faceClearKey,
      stage,
      DailyRitualStageSpec.faceClear,
    );
    _expectLocalRect(
      tester,
      DailyRitualStageSpec.sealVisualKey,
      stage,
      DailyRitualStageSpec.restingSealVisual,
    );
    _expectLocalRect(
      tester,
      const Key('leonidas-sequence-start'),
      stage,
      DailyRitualStageSpec.restingStart,
    );

    expect(find.byKey(DailyRitualStageSpec.cardArtKey), findsOneWidget);
    expect(find.byKey(const Key('leonidas-card-front')), findsNothing);
    _expectNoSensorClaims();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'completed stage keeps one exact-art surface and measured onward actions',
    (tester) async {
      _setReferenceViewport(tester);
      await tester.pumpWidget(
        _stageApp(
          ritual: _ritual(DailyRitualState.completed),
          onShowEvidence: () {},
          onOpenStarpath: () {},
        ),
      );
      await tester.pump();
      await _decodeExactArt(tester);
      await tester.pumpAndSettle();

      final stage = tester.getRect(find.byKey(DailyRitualStageSpec.stageKey));
      final face = DailyRitualStageSpec.faceClear;
      _expectRect(stage, DailyRitualStageSpec.stageViewport);
      _expectLocalRect(
        tester,
        DailyRitualStageSpec.cardSurfaceKey,
        stage,
        DailyRitualStageSpec.keepsakeCard,
      );
      _expectLocalRect(
        tester,
        DailyRitualStageSpec.evidenceKey,
        stage,
        DailyRitualStageSpec.evidenceAction,
      );
      _expectLocalRect(
        tester,
        DailyRitualStageSpec.starpathKey,
        stage,
        DailyRitualStageSpec.starpathAction,
      );

      final copy = _localRect(
        tester,
        DailyRitualStageSpec.completedCopyKey,
        stage,
      );
      expect(copy.left, closeTo(DailyRitualStageSpec.keepsakeCopy.left, 0.1));
      expect(copy.top, closeTo(DailyRitualStageSpec.keepsakeCopy.top, 0.1));
      expect(
        copy.right,
        lessThanOrEqualTo(DailyRitualStageSpec.keepsakeCopy.right),
      );
      expect(face.overlaps(copy), isFalse);

      final phase = _localRect(
        tester,
        const Key('leonidas-phase-label'),
        stage,
      );
      expect(face.overlaps(phase), isFalse);
      expect(
        tester.widget<Text>(find.byKey(const Key('leonidas-phase-label'))).data,
        'Today’s ritual is complete.',
      );

      expect(find.byKey(DailyRitualStageSpec.cardArtKey), findsOneWidget);
      expect(find.byKey(const Key('leonidas-card-front')), findsOneWidget);
      final image = tester.widget<Image>(
        find.byKey(DailyRitualStageSpec.cardArtKey),
      );
      expect(image.fit, BoxFit.contain);
      expect(find.text('Review evidence'), findsOneWidget);
      expect(find.text('Continue to Starpath'), findsOneWidget);
      expect(find.text(_interpretation), findsOneWidget);
      _expectNoSensorClaims();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'C2 expands below the face and settles to completed onward flow',
    (tester) async {
      _setReferenceViewport(tester);
      final voice = _HangingVoice();
      await tester.pumpWidget(
        _stageApp(
          ritual: _ritual(DailyRitualState.assigned),
          voice: voice,
          onShowEvidence: () {},
          onOpenStarpath: () {},
        ),
      );
      await tester.pump();
      await _decodeExactArt(tester);

      await tester.tap(find.byKey(const Key('leonidas-sequence-start')));
      await tester.pump(DailyRitualStageSpec.startTransition);
      final hold = await tester.startGesture(
        tester.getCenter(find.byKey(DailyRitualStageSpec.sealHitKey)),
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      await hold.up();

      final stage = tester.getRect(find.byKey(DailyRitualStageSpec.stageKey));
      _expectLocalRect(
        tester,
        DailyRitualStageSpec.cardSurfaceKey,
        stage,
        DailyRitualStageSpec.revealedCard,
      );
      _expectLocalRect(
        tester,
        const Key('ritual-complete'),
        stage,
        DailyRitualStageSpec.revealedFinish,
      );
      expect(find.byKey(const Key('ritual-complete')), findsOneWidget);

      await tester.tap(find.byKey(const Key('ritual-complete')));
      await tester.pump();
      await tester.pump(DailyRitualStageSpec.c2Expand);

      _expectLocalRect(
        tester,
        DailyRitualStageSpec.cardSurfaceKey,
        stage,
        DailyRitualStageSpec.c2Card,
      );
      final face = DailyRitualStageSpec.faceClear;
      final c2Card = _localRect(
        tester,
        DailyRitualStageSpec.cardSurfaceKey,
        stage,
      );
      final caption = _localRect(
        tester,
        DailyRitualStageSpec.c2CaptionKey,
        stage,
      );
      final completionMessage = _localRect(
        tester,
        const Key('leonidas-phase-label'),
        stage,
      );
      expect(face.overlaps(c2Card), isFalse);
      expect(face.overlaps(caption), isFalse);
      expect(face.overlaps(completionMessage), isFalse);
      expect(caption.top, closeTo(DailyRitualStageSpec.c2Caption.top, 0.1));
      expect(find.text('Today’s ritual is complete.'), findsOneWidget);
      expect(find.byKey(const Key('leonidas-closing-skip')), findsOneWidget);
      expect(find.byKey(const Key('ritual-complete')), findsNothing);
      expect(find.byKey(DailyRitualStageSpec.evidenceKey), findsNothing);
      expect(find.byKey(DailyRitualStageSpec.cardArtKey), findsOneWidget);
      expect(voice.lines, hasLength(1));

      await tester.tap(find.byKey(const Key('leonidas-closing-skip')));
      await tester.pump();
      await tester.pump(DailyRitualStageSpec.c2Settle);
      _expectLocalRect(
        tester,
        DailyRitualStageSpec.cardSurfaceKey,
        stage,
        DailyRitualStageSpec.keepsakeCard,
      );
      expect(find.byKey(DailyRitualStageSpec.evidenceKey), findsOneWidget);
      expect(find.byKey(DailyRitualStageSpec.starpathKey), findsOneWidget);
      expect(find.text(_interpretation), findsOneWidget);
      expect(find.byKey(DailyRitualStageSpec.cardArtKey), findsOneWidget);
      _expectNoSensorClaims();
      expect(tester.takeException(), isNull);
    },
  );
}

const _artPath =
    'assets/images/tarot/modern-rider-waite/major/08-strength.webp';
const _interpretation = 'Patience is the stronger path.';

Widget _stageApp({
  required DailyRitual ritual,
  LeonidasVoice voice = const _UnavailableVoice(),
  VoidCallback? onShowEvidence,
  VoidCallback? onOpenStarpath,
}) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(
    body: Stack(
      children: [
        Positioned(
          left: DailyRitualStageSpec.stageViewport.left,
          top: DailyRitualStageSpec.stageViewport.top,
          width: DailyRitualStageSpec.stageViewport.width,
          child: LeonidasRitualSequence(
            ritual: ritual,
            voice: voice,
            onReveal: () async => true,
            onComplete: () async => true,
            onShowEvidence: onShowEvidence,
            onOpenStarpath: onOpenStarpath,
            prepareExactMedia: (_) async => true,
            monotonicNow: () => Duration(
              microseconds: TestWidgetsFlutterBinding.instance.clock
                  .now()
                  .microsecondsSinceEpoch,
            ),
          ),
        ),
      ],
    ),
  ),
);

void _setReferenceViewport(WidgetTester tester) {
  tester.view.physicalSize = DailyRitualStageSpec.referenceViewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _decodeExactArt(WidgetTester tester) async {
  final context = tester.element(find.byKey(DailyRitualStageSpec.stageKey));
  await tester.runAsync<void>(
    () => precacheImage(const AssetImage(_artPath), context),
  );
  await tester.pump();
  await tester.pump();
}

Rect _localRect(WidgetTester tester, Key key, Rect stage) =>
    tester.getRect(find.byKey(key)).shift(Offset(-stage.left, -stage.top));

void _expectLocalRect(
  WidgetTester tester,
  Key key,
  Rect stage,
  Rect expected,
) => _expectRect(_localRect(tester, key, stage), expected);

void _expectRect(Rect actual, Rect expected) {
  expect(actual.left, closeTo(expected.left, 0.1));
  expect(actual.top, closeTo(expected.top, 0.1));
  expect(actual.width, closeTo(expected.width, 0.1));
  expect(actual.height, closeTo(expected.height, 0.1));
}

void _expectNoSensorClaims() {
  expect(find.textContaining('finger', findRichText: true), findsNothing);
  expect(find.textContaining('anatomy', findRichText: true), findsNothing);
  expect(find.textContaining('sensor', findRichText: true), findsNothing);
  expect(
    find.textContaining('energy reading', findRichText: true),
    findsNothing,
  );
}

class _HangingVoice implements LeonidasVoice {
  final List<String> lines = [];

  @override
  Future<bool> speak(String text) {
    lines.add(text);
    return Completer<bool>().future;
  }

  @override
  Future<void> stop() async {}
}

class _UnavailableVoice implements LeonidasVoice {
  const _UnavailableVoice();

  @override
  Future<bool> speak(String text) async => false;

  @override
  Future<void> stop() async {}
}

DailyRitual _ritual(DailyRitualState state) => DailyRitual(
  assignmentId: '00000000-0000-4000-8000-000000000901',
  date: DateTime.utc(2026, 9, 2),
  mode: DailyRitualMode.tarot,
  revision: const RitualRevision(
    id: '00000000-0000-4000-8000-000000000902',
    number: 1,
  ),
  title: 'Strength',
  art: const RitualArt(
    key: 'strength',
    alt: 'Strength tarot card: a calm figure beside a lion',
  ),
  interpretation: _interpretation,
  guidance: 'Inspect the evidence before choosing what to research.',
  marketLabel: 'Tarot reflection',
  ideas: const [],
  evidence: const [],
  rowan: const RitualCounsel(
    scriptRevisionId: '00000000-0000-4000-8000-000000000903',
    surface: 'daily_ritual',
    body: 'The choice remains yours.',
    riskFooter: 'Reflection only; not advice.',
  ),
  version: state == DailyRitualState.assigned ? 1 : 3,
  state: state,
  revealedAt: state == DailyRitualState.assigned
      ? null
      : DateTime.utc(2026, 9, 2, 12, 10),
  completedAt: state == DailyRitualState.completed
      ? DateTime.utc(2026, 9, 2, 12, 20)
      : null,
  demo: RitualDisclosure(
    isDemo: false,
    observedAt: DateTime.utc(2026, 9, 2, 12),
    sourceLabel: 'Argus editorial',
    limitations: const ['Educational context only.'],
  ),
);
