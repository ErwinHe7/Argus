import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/features/ritual/domain/daily_ritual.dart';
import 'package:ritual_investing_app/features/ritual/presentation/daily_ritual_stage_spec.dart';
import 'package:ritual_investing_app/features/ritual/presentation/leonidas_ritual_sequence.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('assigned entry is passive until explicit Start', (tester) async {
    _setPhoneViewport(tester);
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
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Start your daily ritual'), findsOneWidget);
    expect(find.byKey(const Key('daily-ritual-card-art')), findsOneWidget);
    expect(find.byKey(const Key('leonidas-card-front')), findsNothing);
    expect(revealCount, 0);
    expect(voice.lines, isEmpty);
  });

  testWidgets('unavailable content is fail-closed with authority retry', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    var retries = 0;

    await tester.pumpWidget(
      _testApp(
        ritual: _ritual(
          DailyRitualState.assigned,
          contentAvailability: RitualContentAvailability.unavailable,
        ),
        voice: _UnavailableVoice(),
        onReveal: () async => true,
        onRevalidate: () async => retries += 1,
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('leonidas-sequence-start')), findsNothing);
    expect(find.byKey(const Key('leonidas-card-front')), findsNothing);
    expect(
      find.text(
        'Today’s ritual content is unavailable. Nothing unverified was shown.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('daily-ritual-content-retry')));
    await tester.pump();
    expect(retries, 1);
  });

  testWidgets('completed unavailable content keeps only trusted onward exits', (
    tester,
  ) async {
    _setPhoneViewport(tester);

    await tester.pumpWidget(
      _testApp(
        ritual: _ritual(
          DailyRitualState.completed,
          contentAvailability: RitualContentAvailability.unavailable,
        ),
        voice: _UnavailableVoice(),
        onReveal: () async => true,
        onShowEvidence: () {},
        onOpenStarpath: () {},
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('leonidas-card-front')), findsNothing);
    expect(find.text('Strength'), findsNothing);
    expect(find.byKey(const Key('ritual-complete')), findsNothing);
    expect(find.byKey(const Key('leonidas-evidence')), findsOneWidget);
    expect(find.byKey(const Key('leonidas-starpath')), findsOneWidget);
  });

  for (final releaseAfter in <Duration>[
    const Duration(milliseconds: 100),
    const Duration(milliseconds: 4900),
  ]) {
    testWidgets(
      'release after ${releaseAfter.inMilliseconds}ms cancels without reveal',
      (tester) async {
        _setPhoneViewport(tester);
        var revealCount = 0;
        await tester.pumpWidget(
          _testApp(
            ritual: _ritual(DailyRitualState.assigned),
            voice: _UnavailableVoice(),
            onReveal: () async {
              revealCount += 1;
              return true;
            },
          ),
        );

        await tester.tap(find.byKey(const Key('leonidas-sequence-start')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Hold to attune for 5 seconds.'), findsOneWidget);
        final seal = find.bySemanticsLabel('Hold to attune');
        final gesture = await tester.startGesture(tester.getCenter(seal));
        await tester.pump();
        await tester.pump(releaseAfter);
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 250));

        expect(revealCount, 0);
        expect(find.byKey(const Key('leonidas-card-front')), findsNothing);
        expect(
          find.text('You let go. Was the moment not right?'),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('continuous hold dispatches one reveal at exactly five seconds', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    var revealCount = 0;
    await tester.pumpWidget(
      _testApp(
        ritual: _ritual(DailyRitualState.assigned),
        voice: _UnavailableVoice(),
        onReveal: () async {
          revealCount += 1;
          return true;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('leonidas-sequence-start')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final seal = find.bySemanticsLabel('Hold to attune');
    final gesture = await tester.startGesture(tester.getCenter(seal));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 4999));
    expect(revealCount, 0);

    await tester.pump(const Duration(milliseconds: 1));
    expect(revealCount, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(revealCount, 1);
    await gesture.up();
  });

  testWidgets(
    'assistive semantic activation and cancel do not invoke pointer hold',
    (tester) async {
      final semantics = tester.ensureSemantics();
      _setPhoneViewport(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(
            accessibleNavigation: true,
            disableAnimations: true,
          );
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      var revealCount = 0;
      await tester.pumpWidget(
        _testApp(
          ritual: _ritual(DailyRitualState.assigned),
          voice: _UnavailableVoice(),
          onReveal: () async {
            revealCount += 1;
            return true;
          },
        ),
      );
      await tester.tap(find.byKey(const Key('leonidas-sequence-start')));
      await tester.pump();
      await tester.pump(DailyRitualStageSpec.startTransition);

      var seal = tester.getSemantics(find.bySemanticsLabel('Begin ritual'));
      expect(seal.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.semantics.tap(find.semantics.byLabel('Begin ritual'));
      await tester.pump(const Duration(milliseconds: 4900));

      seal = tester.getSemantics(find.bySemanticsLabel('Begin ritual'));
      expect(
        seal.getSemanticsData().hasAction(SemanticsAction.dismiss),
        isTrue,
      );
      tester.semantics.dismiss(find.semantics.byLabel('Begin ritual'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(revealCount, 0);
      expect(
        find.text('You let go. Was the moment not right?'),
        findsOneWidget,
      );

      tester.semantics.tap(find.semantics.byLabel('Begin ritual'));
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      expect(revealCount, 1);
      expect(find.byKey(const Key('leonidas-card-front')), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets('accepted hold waits concealed for delayed matching preflight', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    final matchingPreflight = Completer<bool>();
    var preflightChecks = 0;
    var revealCount = 0;
    await tester.pumpWidget(
      _testApp(
        ritual: _ritual(DailyRitualState.assigned),
        voice: _UnavailableVoice(),
        onReveal: () async {
          preflightChecks += 1;
          revealCount += 1;
          return revealCount == 1;
        },
        prepareExactMedia: (_) => matchingPreflight.future,
      ),
    );

    await tester.tap(find.byKey(const Key('leonidas-sequence-start')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final seal = find.bySemanticsLabel('Hold to attune');
    final gesture = await tester.startGesture(tester.getCenter(seal));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));

    expect(preflightChecks, 0);
    expect(revealCount, 0);
    expect(find.byKey(const Key('leonidas-card-front')), findsNothing);

    matchingPreflight.complete(true);
    await tester.pump();
    await tester.pump();
    expect(revealCount, 1);
    expect(preflightChecks, 1);
    await gesture.up();
  });

  testWidgets(
    'tab invisibility cancels and restores Leonidas acknowledgement',
    (tester) async {
      _setPhoneViewport(tester);
      final tabVisible = ValueNotifier<bool>(true);
      addTearDown(tabVisible.dispose);
      var revealCount = 0;

      await tester.pumpWidget(
        _testApp(
          ritual: _ritual(DailyRitualState.assigned),
          voice: _UnavailableVoice(),
          onReveal: () async {
            revealCount += 1;
            return true;
          },
          tabVisibility: tabVisible,
        ),
      );
      await tester.tap(find.byKey(const Key('leonidas-sequence-start')));
      await tester.pump();
      await tester.pump(DailyRitualStageSpec.startTransition);
      final gesture = await tester.startGesture(
        tester.getCenter(find.bySemanticsLabel('Hold to attune')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 4900));

      tabVisible.value = false;
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(revealCount, 0);

      tabVisible.value = true;
      await tester.pump();
      await tester.pump();
      await gesture.up();
      expect(
        find.text('You let go. Was the moment not right?'),
        findsOneWidget,
      );
      expect(revealCount, 0);
    },
  );

  testWidgets('image load failure shows retry and never substitutes art', (
    tester,
  ) async {
    _setPhoneViewport(tester);

    await tester.pumpWidget(
      _testApp(
        ritual: _ritual(DailyRitualState.completed),
        voice: _UnavailableVoice(),
        onReveal: () async => true,
        assetBundle: _FailingTarotAssetBundle(rootBundle),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('leonidas-card-front')), findsNothing);
    expect(
      find.text(
        'Today’s exact card is unavailable. Nothing else was substituted.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('daily-ritual-media-retry')), findsOneWidget);
  });

  testWidgets(
    'reveals after one hold and speaks only after one successful Finish',
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
          onComplete: () async => true,
        ),
      );

      expect(find.byKey(const Key('daily-ritual-card-art')), findsOneWidget);
      expect(find.byKey(const Key('leonidas-card-front')), findsNothing);
      expect(find.byKey(const Key('leonidas-portrait-focus')), findsOneWidget);

      await tester.tap(find.byKey(const Key('leonidas-sequence-start')));
      await tester.pump();
      await tester.pump(DailyRitualStageSpec.startTransition);

      expect(find.byKey(const Key('leonidas-portrait-focus')), findsOneWidget);
      expect(find.text('Hold to attune for 5 seconds.'), findsOneWidget);
      expect(revealCount, 0);
      expect(voice.lines, isEmpty);

      final seal = find.bySemanticsLabel('Begin ritual');
      final gesture = await tester.startGesture(tester.getCenter(seal));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));

      expect(revealCount, 1);
      expect(find.byKey(const Key('leonidas-card-front')), findsNothing);

      reveal.complete(true);
      await tester.pumpAndSettle();

      expect(revealCount, 1);
      expect(find.byKey(const Key('leonidas-card-front')), findsOneWidget);
      expect(find.byKey(const Key('leonidas-portrait-focus')), findsOneWidget);
      expect(find.text('Strength'), findsOneWidget);
      expect(find.byKey(const Key('ritual-complete')), findsOneWidget);
      expect(find.byKey(const Key('leonidas-evidence')), findsNothing);
      expect(voice.lines, isEmpty);

      await gesture.up();
      await tester.tap(find.byKey(const Key('ritual-complete')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('leonidas-evidence')), findsOneWidget);
      expect(voice.lines, hasLength(1));
      expect(
        voice.lines.single,
        'Carry the signal with you. I’ll meet you here tomorrow.',
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
    await tester.pump();
    await tester.pump(DailyRitualStageSpec.startTransition);
    final seal = find.bySemanticsLabel('Begin ritual');
    final gesture = await tester.startGesture(tester.getCenter(seal));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    await gesture.up();

    expect(find.byKey(const Key('leonidas-card-front')), findsNothing);
    expect(find.byKey(const Key('leonidas-portrait-focus')), findsOneWidget);
    expect(
      find.text("The ritual could not be opened. Try again when you're ready."),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Begin ritual'), findsOneWidget);
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
    await tester.pump();
    await tester.pump(DailyRitualStageSpec.startTransition);
    final seal = find.bySemanticsLabel('Begin ritual');
    final gesture = await tester.startGesture(tester.getCenter(seal));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    await gesture.up();

    expect(find.bySemanticsLabel('Begin ritual'), findsOneWidget);
    expect(find.textContaining('could not be opened'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a restored completed ritual opens onward without C2 speech or Replay',
    (tester) async {
      _setPhoneViewport(tester);
      final voice = _UnavailableVoice();
      await tester.pumpWidget(
        _testApp(
          ritual: _ritual(DailyRitualState.completed),
          voice: voice,
          onReveal: () async => true,
          onShowEvidence: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('leonidas-card-front')), findsOneWidget);
      expect(find.byKey(const Key('leonidas-portrait-focus')), findsOneWidget);
      expect(find.byKey(const Key('leonidas-sequence-replay')), findsNothing);
      expect(find.byKey(const Key('leonidas-evidence')), findsOneWidget);
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
        onComplete: () async => true,
        onShowEvidence: () {},
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('leonidas-voice-toggle')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('leonidas-sequence-start')));
    await tester.pump();
    await tester.pump(DailyRitualStageSpec.startTransition);
    final seal = find.bySemanticsLabel('Begin ritual');
    final gesture = await tester.startGesture(tester.getCenter(seal));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    await gesture.up();
    await tester.tap(find.byKey(const Key('ritual-complete')));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(revealCount, 1);
    expect(voice.lines, isEmpty);
    expect(voice.stopCount, 0);
    expect(find.byKey(const Key('leonidas-evidence')), findsOneWidget);
    expect(find.text('Strength'), findsOneWidget);
  });

  testWidgets('Skip stops a stalled native voice and opens onward once', (
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
        onComplete: () async => true,
        onShowEvidence: () {},
      ),
    );

    await tester.tap(find.byKey(const Key('leonidas-sequence-start')));
    await tester.pump();
    await tester.pump(DailyRitualStageSpec.startTransition);
    final seal = find.bySemanticsLabel('Begin ritual');
    final gesture = await tester.startGesture(tester.getCenter(seal));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    await gesture.up();
    await tester.tap(find.byKey(const Key('ritual-complete')));
    await tester.pump();

    expect(revealCount, 1);
    expect(voice.lines, hasLength(1));
    expect(find.byKey(const Key('leonidas-closing-skip')), findsOneWidget);

    await tester.tap(find.byKey(const Key('leonidas-closing-skip')));
    await tester.pump();

    expect(voice.stopCount, 1);
    expect(find.byKey(const Key('leonidas-evidence')), findsOneWidget);
  });

  testWidgets('long interpretation remains reachable at 2x without C2 replay', (
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
        onShowEvidence: () {},
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.takeException(), isNull);
    expect(find.text(longInterpretation), findsOneWidget);
    expect(find.textContaining(longCounsel), findsNothing);
    expect(find.byKey(const Key('leonidas-evidence')), findsOneWidget);
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
  Future<void> Function()? onRevalidate,
  VoidCallback? onShowEvidence,
  VoidCallback? onOpenStarpath,
  bool artDecodeSucceeds = true,
  AssetBundle? assetBundle,
  Future<bool> Function(DailyRitual)? prepareExactMedia,
  Future<bool> Function()? onComplete,
  ValueListenable<bool>? tabVisibility,
}) {
  final sequence = SingleChildScrollView(
    child: LeonidasRitualSequence(
      ritual: ritual,
      voice: voice,
      onReveal: onReveal,
      onRevalidate: onRevalidate,
      onComplete: onComplete,
      onShowEvidence: onShowEvidence,
      onOpenStarpath: onOpenStarpath,
      useBundledArtwork: artDecodeSucceeds,
      prepareExactMedia:
          prepareExactMedia ?? (artDecodeSucceeds ? (_) async => true : null),
      monotonicNow: () => Duration(
        microseconds: TestWidgetsFlutterBinding.instance.clock
            .now()
            .microsecondsSinceEpoch,
      ),
    ),
  );
  final app = MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: tabVisibility == null
          ? sequence
          : ValueListenableBuilder<bool>(
              valueListenable: tabVisibility,
              child: sequence,
              builder: (context, visible, child) =>
                  TickerMode(enabled: visible, child: child!),
            ),
    ),
  );
  return assetBundle == null
      ? app
      : DefaultAssetBundle(bundle: assetBundle, child: app);
}

class _FailingTarotAssetBundle extends CachingAssetBundle {
  _FailingTarotAssetBundle(this.delegate);

  final AssetBundle delegate;

  @override
  Future<ByteData> load(String key) {
    if (key.contains('/tarot/')) {
      return Future<ByteData>.error(
        StateError('intentional tarot image failure'),
      );
    }
    return delegate.load(key);
  }
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
  RitualContentAvailability contentAvailability =
      RitualContentAvailability.available,
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
  contentAvailability: contentAvailability,
);
