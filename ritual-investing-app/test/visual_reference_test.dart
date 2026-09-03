@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/ritual/application/daily_ritual_controller.dart';
import 'package:ritual_investing_app/features/ritual/application/leonidas_voice.dart';
import 'package:ritual_investing_app/features/ritual/data/daily_ritual_repository.dart';
import 'package:ritual_investing_app/features/ritual/domain/daily_ritual.dart';
import 'package:ritual_investing_app/features/ritual/presentation/daily_ritual_screen.dart';
import 'package:ritual_investing_app/features/ritual/presentation/daily_ritual_stage_controller.dart';
import 'package:ritual_investing_app/features/ritual/presentation/daily_ritual_stage_spec.dart';

void main() {
  setUpAll(() async {
    await _loadFont('Inter', 'assets/fonts/Inter-Variable.ttf');
    await _loadFont(
      'LibreBaskerville',
      'assets/fonts/LibreBaskerville-Variable.ttf',
    );
    await _loadFont('MaterialIcons', 'fonts/MaterialIcons-Regular.otf');
  });

  for (final atmosphere in _GoldenAtmosphere.values) {
    testWidgets(
      'approved Daily Ritual journey remains stable in ${atmosphere.name}',
      (tester) async {
        tester.view.physicalSize = DailyRitualStageSpec.referenceViewport;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        var elapsed = Duration.zero;
        final service = _GoldenRitualService();
        final controller = DailyRitualController(
          repository: DailyRitualRepository(
            service: service,
            cache: MemoryReadCache(),
          ),
        );
        addTearDown(controller.dispose);
        await controller.load();

        await tester.pumpWidget(
          RepaintBoundary(
            key: _goldenRoot,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: atmosphere.themeMode,
              home: Scaffold(
                body: DailyRitualScreen(
                  controller: controller,
                  onOpenCoven: () {},
                  onOpenStarpath: () {},
                  onToggleTheme: () {},
                  leonidasVoice: _NeverCompletingVoice(),
                  monotonicNow: () => elapsed,
                ),
                bottomNavigationBar: NavigationBar(
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.auto_awesome),
                      label: 'Ritual',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.stars_rounded),
                      label: 'Starpath',
                    ),
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
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _precacheRitualAssets(tester);

        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.text('Start your daily ritual'), findsOneWidget);
        await _matchCheckpoint(tester, atmosphere, 'resting');

        await tester.tap(find.byKey(const Key('leonidas-sequence-start')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('daily-ritual-immersive')), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);

        final hold = await tester.startGesture(
          tester.getCenter(
            find.byKey(const Key('daily-ritual-seal-hit-region')),
          ),
        );
        await tester.pump();
        await controller.authorityIdle;
        elapsed = const Duration(seconds: 3);
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('Stay with me. 3 of 5 seconds.'), findsOneWidget);
        _expectImmersiveInvariants(tester);
        await _matchCheckpoint(tester, atmosphere, 'holding_60');

        elapsed = const Duration(seconds: 5, milliseconds: 1);
        await tester.pump(const Duration(milliseconds: 50));
        await hold.up();
        await controller.authorityIdle;
        await tester.pumpAndSettle();
        expect(find.text('Reading revealed'), findsOneWidget);
        expect(find.byKey(const Key('leonidas-card-front')), findsOneWidget);
        _expectImmersiveInvariants(tester);
        await _matchCheckpoint(tester, atmosphere, 'revealed');

        await tester.tap(find.byKey(const Key('ritual-complete')));
        await controller.authorityIdle;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byKey(const Key('leonidas-closing-skip')), findsOneWidget);
        expect(find.text(dailyRitualClosingCaption), findsOneWidget);
        _expectImmersiveInvariants(tester);
        await _matchCheckpoint(tester, atmosphere, 'c2_closing');

        await tester.tap(find.byKey(const Key('leonidas-closing-skip')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('leonidas-evidence')), findsOneWidget);
        expect(find.byKey(const Key('leonidas-starpath')), findsOneWidget);
        _expectImmersiveInvariants(tester);
        await _matchCheckpoint(tester, atmosphere, 'completed_onward');
      },
    );
  }
}

const _goldenRoot = Key('daily-ritual-golden-root');

enum _GoldenAtmosphere {
  light(ThemeMode.light),
  dark(ThemeMode.dark);

  const _GoldenAtmosphere(this.themeMode);

  final ThemeMode themeMode;
}

Future<void> _matchCheckpoint(
  WidgetTester tester,
  _GoldenAtmosphere atmosphere,
  String checkpoint,
) => expectLater(
  find.byKey(_goldenRoot),
  matchesGoldenFile('goldens/daily_ritual_${atmosphere.name}_$checkpoint.png'),
);

void _expectImmersiveInvariants(WidgetTester tester) {
  expect(find.byType(NavigationBar), findsNothing);
  expect(find.byKey(const Key('ritual-search')), findsNothing);
  expect(find.byKey(const Key('ritual-briefings')), findsNothing);
  expect(find.byKey(const Key('theme-toggle')), findsNothing);
  expect(
    find.descendant(
      of: find.byKey(const Key('leonidas-ritual-sequence')),
      matching: find.byType(Scrollable),
    ),
    findsNothing,
  );
  expect(find.byKey(const Key('leonidas-portrait-focus')), findsOneWidget);
  expect(tester.takeException(), isNull);
}

Future<void> _precacheRitualAssets(WidgetTester tester) async {
  final context = tester.element(
    find.byKey(const Key('leonidas-ritual-sequence')),
  );
  await tester.runAsync<void>(
    () => Future.wait([
      precacheImage(
        const AssetImage(
          'assets/images/tarot/modern-rider-waite/major/04-the-emperor.webp',
        ),
        context,
      ),
      precacheImage(
        const AssetImage(
          'assets/images/leonidas/leonidas-canonical-scholar-portrait-v1.png',
        ),
        context,
      ),
    ]),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _loadFont(String family, String asset) async {
  final loader = FontLoader(family)..addFont(rootBundle.load(asset));
  await loader.load();
}

class _NeverCompletingVoice implements LeonidasVoice {
  final Completer<bool> _speech = Completer<bool>();

  @override
  Future<bool> speak(String text) => _speech.future;

  @override
  Future<void> stop() async {}
}

class _GoldenRitualService implements DailyRitualService {
  DailyRitualState state = DailyRitualState.assigned;
  int version = 1;

  @override
  Future<DailyRitual> fetchDaily({DailyRitualMode? mode}) async => _ritual;

  @override
  Future<DailyRitual> fetchAssignment(String assignmentId) async => _ritual;

  @override
  Future<List<RitualEvidenceDetail>> fetchEvidence(String assignmentId) async =>
      const [];

  @override
  Future<RitualHistoryPage> fetchHistory({String? cursor}) async =>
      RitualHistoryPage(items: const [], nextCursor: null, hasMore: false);

  @override
  Future<DailyRitual> reveal(String assignmentId, int expectedVersion) async {
    state = DailyRitualState.revealed;
    version = expectedVersion + 1;
    return _ritual;
  }

  @override
  Future<DailyRitual> complete(String assignmentId, int expectedVersion) async {
    state = DailyRitualState.completed;
    version = expectedVersion + 1;
    return _ritual;
  }

  DailyRitual get _ritual => DailyRitual(
    assignmentId: '00000000-0000-4000-8000-000000000101',
    date: DateTime.utc(2026, 8, 25),
    mode: DailyRitualMode.tarot,
    revision: const RitualRevision(
      id: '10000000-0000-4000-8000-000000000001',
      number: 1,
    ),
    title: 'Direction, not urgency.',
    art: const RitualArt(
      key: 'the_emperor',
      alt: 'The Emperor tarot card: a ruler sits on a ram-carved throne before mountains',
    ),
    interpretation: 'Direction is an invitation, not an instruction.',
    guidance: 'Inspect sources before choosing what to research.',
    marketLabel: 'Market-informed Demo evidence',
    ideas: const [],
    evidence: const [],
    rowan: const RitualCounsel(
      scriptRevisionId: '10000000-0000-4000-8000-000000000002',
      surface: 'daily_ritual',
      body: 'Notice without rushing.',
      riskFooter: 'Demo counsel; not advice.',
    ),
    version: version,
    state: state,
    revealedAt: state == DailyRitualState.assigned
        ? null
        : DateTime.utc(2026, 8, 25, 12, 10),
    completedAt: state == DailyRitualState.completed
        ? DateTime.utc(2026, 8, 25, 12, 20)
        : null,
    demo: RitualDisclosure(
      isDemo: true,
      observedAt: DateTime.utc(2026, 8, 25, 12),
      sourceLabel: 'Deterministic fixture',
      limitations: const ['Fictional scenario; no live provider.'],
    ),
  );
}
