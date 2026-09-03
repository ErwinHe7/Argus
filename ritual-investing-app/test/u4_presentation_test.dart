import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/ritual/application/daily_ritual_controller.dart';
import 'package:ritual_investing_app/features/ritual/application/leonidas_voice.dart';
import 'package:ritual_investing_app/features/ritual/data/daily_ritual_repository.dart';
import 'package:ritual_investing_app/features/ritual/domain/daily_ritual.dart';
import 'package:ritual_investing_app/features/ritual/presentation/daily_ritual_screen.dart';
import 'package:ritual_investing_app/features/ritual/presentation/daily_ritual_stage_spec.dart';
import 'package:ritual_investing_app/features/search/application/controller.dart'
    as member_search;
import 'package:ritual_investing_app/features/search/data/repository.dart';
import 'package:ritual_investing_app/features/search/domain/model.dart';
import 'package:ritual_investing_app/features/search/presentation/search_screen.dart';

void main() {
  testWidgets('assigned ritual conceals its artwork until reveal succeeds', (
    tester,
  ) async {
    _setReducedMotionPhoneViewport(tester);
    var elapsed = Duration.zero;
    final controller = DailyRitualController(
      repository: DailyRitualRepository(
        service: _RitualService(state: DailyRitualState.assigned),
        cache: MemoryReadCache(),
      ),
    );
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: DailyRitualScreen(
            controller: controller,
            onOpenCoven: () {},
            leonidasVoice: const _ImmediateLeonidasVoice(),
            monotonicNow: () => elapsed,
            prepareExactMedia: (_) async => true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await _decodeExactArt(
      tester,
      'assets/images/tarot/modern-rider-waite/major/09-the-hermit.webp',
    );

    expect(find.byKey(const Key('daily-ritual-card-art')), findsOneWidget);
    expect(find.byKey(const Key('leonidas-card-front')), findsNothing);
    expect(
      find.bySemanticsLabel(
        'The Hermit tarot card: an elder holds a star lantern on a snowy mountain',
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('leonidas-sequence-start')));
    await tester.pumpAndSettle();
    final hold = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('daily-ritual-seal-hit-region'))),
    );
    await tester.pump();
    expect(find.byKey(const Key('leonidas-phase-label')), findsNothing);
    expect(find.text('Stay with me · 0 of 5 seconds'), findsOneWidget);
    elapsed = const Duration(seconds: 5, milliseconds: 1);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    await hold.up();
    await controller.authorityIdle;
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('leonidas-phase-label'))).data,
      'Reading revealed',
    );
    expect(find.byKey(const Key('daily-ritual-card-art')), findsOneWidget);
    expect(find.byKey(const Key('leonidas-card-front')), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'The Hermit tarot card: an elder holds a star lantern on a snowy mountain',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('leonidas-ritual-sequence')),
        matching: find.byType(Scrollable),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'Start crossfades attunement in place while shell chrome stays visible',
    (tester) async {
      _setPhoneViewport(tester);
      final controller = DailyRitualController(
        repository: DailyRitualRepository(
          service: _RitualService(state: DailyRitualState.assigned),
          cache: MemoryReadCache(),
        ),
      );
      await controller.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: DailyRitualScreen(
              controller: controller,
              onOpenCoven: () {},
              onOpenSearch: () {},
              onOpenBriefings: () {},
              onToggleTheme: () {},
              prepareExactMedia: (_) async => true,
            ),
            bottomNavigationBar: NavigationBar(
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.auto_awesome),
                  label: 'Ritual',
                ),
                NavigationDestination(
                  icon: Icon(Icons.stars),
                  label: 'Starpath',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await _decodeExactArt(
        tester,
        'assets/images/tarot/modern-rider-waite/major/09-the-hermit.webp',
      );

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byKey(const Key('ritual-search')), findsOneWidget);
      expect(find.byKey(const Key('ritual-briefings')), findsOneWidget);
      expect(find.byKey(const Key('theme-toggle')), findsOneWidget);
      expect(find.text('YOUR DAILY SIGNAL'), findsNothing);
      expect(find.text('TODAY’S DAILY RITUAL'), findsOneWidget);
      expect(find.byKey(DailyRitualStageSpec.sealVisualKey), findsNothing);
      expect(
        tester.getSize(find.byKey(DailyRitualStageSpec.stageKey)).width,
        390,
      );
      expect(
        tester.getRect(find.byKey(DailyRitualStageSpec.stageKey)).bottom,
        closeTo(tester.getRect(find.byType(NavigationBar)).top, 0.1),
      );

      await tester.tap(find.byKey(const Key('leonidas-sequence-start')));
      await tester.pump();

      expect(find.byKey(const Key('daily-ritual-immersive')), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byKey(const Key('ritual-search')), findsOneWidget);
      expect(find.byKey(const Key('ritual-briefings')), findsOneWidget);
      expect(find.byKey(const Key('theme-toggle')), findsOneWidget);
      expect(find.byType(CustomScrollView), findsNothing);
      final fade = find.byKey(DailyRitualStageSpec.attunementFadeKey);
      expect(fade, findsOneWidget);
      expect(tester.widget<FadeTransition>(fade).opacity.value, 0);

      await tester.pump(const Duration(milliseconds: 120));
      expect(
        tester.widget<FadeTransition>(fade).opacity.value,
        allOf(greaterThan(0), lessThan(1)),
      );
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
      final seal = tester.getRect(
        find.byKey(DailyRitualStageSpec.sealHitKey),
      );
      final navigation = tester.getRect(find.byType(NavigationBar));
      expect(
        navigation.top - seal.bottom,
        closeTo(DailyRitualStageSpec.sealBottomInset, 0.1),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('leonidas-ritual-sequence')),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'restored revealed ritual remains in place with its shell controls',
    (tester) async {
      _setReducedMotionPhoneViewport(tester);
      final service = _RitualService(
        state: DailyRitualState.revealed,
        version: 2,
      );
      final voice = _RecordingLeonidasVoice();
      final controller = DailyRitualController(
        repository: DailyRitualRepository(
          service: service,
          cache: MemoryReadCache(),
        ),
      );
      await controller.load();
      await tester.pumpWidget(_screenApp(controller: controller, voice: voice));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byKey(const Key('daily-ritual-immersive')), findsNothing);
      await _decodeExactArt(
        tester,
        'assets/images/tarot/modern-rider-waite/major/09-the-hermit.webp',
      );

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byKey(const Key('ritual-search')), findsOneWidget);
      expect(find.byKey(const Key('ritual-briefings')), findsOneWidget);
      expect(find.byKey(const Key('theme-toggle')), findsOneWidget);
      expect(find.text('Reading revealed'), findsOneWidget);
      expect(find.text('Direction, not urgency.'), findsOneWidget);
      expect(find.byKey(const Key('ritual-complete')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('leonidas-ritual-sequence')),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      expect(voice.lines, isEmpty);
      expect(service.revealCalls, 0);
      expect(service.completeCalls, 0);
    },
  );

  testWidgets('restored completed ritual keeps onward actions in place', (
    tester,
  ) async {
    _setReducedMotionPhoneViewport(tester);
    final service = _RitualService();
    final voice = _RecordingLeonidasVoice();
    final controller = DailyRitualController(
      repository: DailyRitualRepository(
        service: service,
        cache: MemoryReadCache(),
      ),
    );
    await controller.load();
    await tester.pumpWidget(_screenApp(controller: controller, voice: voice));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const Key('daily-ritual-immersive')), findsNothing);
    await _decodeExactArt(
      tester,
      'assets/images/tarot/modern-rider-waite/major/09-the-hermit.webp',
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const Key('ritual-search')), findsOneWidget);
    expect(find.byKey(const Key('ritual-briefings')), findsOneWidget);
    expect(find.byKey(const Key('theme-toggle')), findsOneWidget);
    expect(find.text('Today’s ritual is complete.'), findsOneWidget);
    expect(find.byKey(const Key('leonidas-evidence')), findsOneWidget);
    expect(find.byKey(const Key('leonidas-starpath')), findsOneWidget);
    expect(find.byKey(const Key('leonidas-closing-skip')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('leonidas-ritual-sequence')),
        matching: find.byType(Scrollable),
      ),
      findsNothing,
    );
    expect(voice.lines, isEmpty);
    expect(service.completeCalls, 0);
  });

  testWidgets('failed reveal remains actionable and announces the failure', (
    tester,
  ) async {
    _setReducedMotionPhoneViewport(tester);
    var elapsed = Duration.zero;
    final controller = DailyRitualController(
      repository: DailyRitualRepository(
        service: _RitualService(
          state: DailyRitualState.assigned,
          failReveal: true,
        ),
        cache: MemoryReadCache(),
      ),
    );
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: DailyRitualScreen(
            controller: controller,
            onOpenCoven: () {},
            leonidasVoice: const _ImmediateLeonidasVoice(),
            monotonicNow: () => elapsed,
            prepareExactMedia: (_) async => true,
          ),
        ),
      ),
    );
    await tester.pump();
    await _decodeExactArt(
      tester,
      'assets/images/tarot/modern-rider-waite/major/09-the-hermit.webp',
    );

    await tester.tap(find.byKey(const Key('leonidas-sequence-start')));
    await tester.pumpAndSettle();
    final hold = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('daily-ritual-seal-hit-region'))),
    );
    await tester.pump();
    expect(find.byKey(const Key('leonidas-phase-label')), findsNothing);
    expect(find.text('Stay with me · 0 of 5 seconds'), findsOneWidget);
    elapsed = const Duration(seconds: 5, milliseconds: 1);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    await hold.up();
    await controller.authorityIdle;
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('leonidas-phase-label')), findsNothing);
    expect(
      find.textContaining('The ritual could not be opened'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Begin ritual'), findsOneWidget);
    expect(find.byKey(const Key('leonidas-card-front')), findsNothing);
  });

  testWidgets('failed Finish preserves the reading and retries once', (
    tester,
  ) async {
    _setReducedMotionPhoneViewport(tester);
    final service = _RitualService(
      state: DailyRitualState.revealed,
      version: 2,
      completeFailures: 1,
    );
    final controller = DailyRitualController(
      repository: DailyRitualRepository(
        service: service,
        cache: MemoryReadCache(),
      ),
    );
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: DailyRitualScreen(
            controller: controller,
            onOpenCoven: () {},
            leonidasVoice: const _ImmediateLeonidasVoice(),
          ),
        ),
      ),
    );
    await tester.pump();
    await _decodeExactArt(
      tester,
      'assets/images/tarot/modern-rider-waite/major/09-the-hermit.webp',
    );

    await tester.tap(find.byKey(const Key('ritual-complete')));
    await tester.pumpAndSettle();

    expect(find.text('Finish paused safely'), findsNothing);
    expect(find.text('Direction, not urgency.'), findsOneWidget);
    expect(find.byKey(const Key('leonidas-card-front')), findsOneWidget);
    expect(find.byKey(const Key('daily-ritual-finish-error')), findsOneWidget);
    expect(find.byKey(const Key('ritual-complete')), findsOneWidget);
    expect(find.text('Today’s ritual is complete.'), findsNothing);
    expect(controller.state.value?.state, DailyRitualState.revealed);

    await tester.tap(find.byKey(const Key('ritual-complete')));
    await tester.pumpAndSettle();

    expect(service.completeCalls, 2);
    expect(controller.state.value?.state, DailyRitualState.completed);
    expect(find.byKey(const Key('leonidas-evidence')), findsOneWidget);
  });

  testWidgets('production ritual shows only content for the drawn card', (
    tester,
  ) async {
    _setReducedMotionPhoneViewport(tester);
    final ritual = _deathRitual();
    final controller = DailyRitualController(
      repository: DailyRitualRepository(
        service: _SingleRitualService(ritual),
        cache: MemoryReadCache(),
      ),
    );
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: DailyRitualScreen(controller: controller, onOpenCoven: () {}),
        ),
      ),
    );
    await tester.pump();
    await _decodeExactArt(
      tester,
      'assets/images/tarot/modern-rider-waite/major/13-death.webp',
    );
    await tester.pumpAndSettle();

    expect(find.text('Death'), findsOneWidget);
    expect(find.text(ritual.interpretation), findsOneWidget);
    expect(find.text(ritual.guidance), findsNothing);
    expect(find.byKey(const Key('daily-ritual-card-art')), findsOneWidget);
    expect(find.byKey(const Key('daily-ritual-media-retry')), findsNothing);
    final deathImage = tester.widget<Image>(
      find.byKey(const Key('daily-ritual-card-art')),
    );
    final deathProvider = deathImage.image as AssetImage;
    expect(
      deathProvider.assetName,
      'assets/images/tarot/modern-rider-waite/major/13-death.webp',
    );
    expect(find.textContaining('Demo'), findsNothing);
    expect(find.textContaining('demo'), findsNothing);
    expect(find.text("THE CARD'S CONSTELLATION"), findsNothing);
    expect(find.text('Market-informed Demo'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('leonidas-ritual-sequence')),
        matching: find.byType(Scrollable),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'daily ritual renders the explicitly assigned Major Arcana artwork',
    (tester) async {
      _setReducedMotionPhoneViewport(tester);
      final controller = DailyRitualController(
        repository: DailyRitualRepository(
          service: _RitualService(),
          cache: MemoryReadCache(),
        ),
      );
      await controller.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: DailyRitualScreen(controller: controller, onOpenCoven: () {}),
          ),
        ),
      );
      await tester.pump();
      await _decodeExactArt(
        tester,
        'assets/images/tarot/modern-rider-waite/major/09-the-hermit.webp',
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(
          'The Hermit tarot card: an elder holds a star lantern on a snowy mountain',
        ),
        findsOneWidget,
      );
      final image = tester.widget<Image>(
        find.byKey(const Key('daily-ritual-card-art')),
      );
      final provider = image.image;
      final assetProvider = provider is ResizeImage
          ? provider.imageProvider as AssetImage
          : provider as AssetImage;
      expect(
        assetProvider.assetName,
        'assets/images/tarot/modern-rider-waite/major/09-the-hermit.webp',
      );
      expect(assetProvider.package, isNull);
      expect(
        assetProvider.keyName,
        'assets/images/tarot/modern-rider-waite/major/09-the-hermit.webp',
      );
      final artworkBytes = await rootBundle.load(assetProvider.keyName);
      expect(artworkBytes.lengthInBytes, greaterThan(100000));
      final renderedSize = tester.getSize(
        find.byKey(const Key('leonidas-card-front')),
      );
      expect(renderedSize, const Size(118, 206));
      expect(image.fit, BoxFit.contain);
      expect(find.byKey(const Key('daily-ritual-card-art')), findsOneWidget);
    },
  );

  testWidgets('evidence preserves its immutable summary while detail retries', (
    tester,
  ) async {
    _setReducedMotionPhoneViewport(tester);
    final service = _RitualService(evidenceFailures: 1, hasEvidence: true);
    final ritual = DailyRitualController(
      repository: DailyRitualRepository(
        service: service,
        cache: MemoryReadCache(),
      ),
    );
    await ritual.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: DailyRitualScreen(
            controller: ritual,
            onOpenCoven: () {},
            onToggleTheme: () {},
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _decodeExactArt(
      tester,
      'assets/images/tarot/modern-rider-waite/major/09-the-hermit.webp',
    );
    await tester.ensureVisible(find.byKey(const Key('leonidas-evidence')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('leonidas-evidence')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ritual-evidence-sheet')), findsOneWidget);
    expect(find.byKey(const Key('ritual-evidence-done')), findsOneWidget);
    expect(find.byKey(const Key('ritual-evidence-retry')), findsOneWidget);
    expect(find.text('Observation'), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);
    expect(
      find.text('The Demo scenario held its fictional range.'),
      findsOneWidget,
    );
    final evidenceScrollable = find.descendant(
      of: find.byKey(const Key('ritual-evidence-sheet')),
      matching: find.byType(Scrollable),
    );
    expect(evidenceScrollable, findsOneWidget);
    final evidencePosition = tester
        .state<ScrollableState>(evidenceScrollable)
        .position;
    expect(evidencePosition.maxScrollExtent, greaterThan(0));
    evidencePosition.jumpTo(evidencePosition.maxScrollExtent);
    await tester.pump();
    await tester.tap(find.byKey(const Key('ritual-evidence-retry')));
    await tester.pumpAndSettle();
    evidencePosition.jumpTo(0);
    await tester.pump();
    expect(find.textContaining('Demo Research Desk'), findsOneWidget);
    expect(find.byKey(const Key('rowan-explain')), findsNothing);
  });

  testWidgets(
    'completed onward flow stays focused and reachable at large text',
    (tester) async {
      _setReducedMotionPhoneViewport(tester);
      var starpathOpened = false;
      final controller = DailyRitualController(
        repository: DailyRitualRepository(
          service: _RitualService(),
          cache: MemoryReadCache(),
        ),
      );
      await controller.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: DailyRitualScreen(
              controller: controller,
              onOpenCoven: () {},
              onOpenStarpath: () => starpathOpened = true,
              onToggleTheme: () {},
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('ritual-history')), findsNothing);
      expect(find.textContaining('Coven'), findsNothing);
      expect(find.textContaining('practice'), findsNothing);
      expect(find.byKey(const Key('rowan-explain')), findsNothing);
      expect(find.byKey(const Key('leonidas-evidence')), findsOneWidget);
      expect(find.byKey(const Key('leonidas-starpath')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('leonidas-evidence'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('leonidas-starpath'))).dy,
        ),
      );
      await tester.ensureVisible(find.byKey(const Key('leonidas-starpath')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('leonidas-starpath')));
      await tester.pumpAndSettle();
      expect(starpathOpened, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shared search restores the retained visible query', (
    tester,
  ) async {
    final controller = member_search.SearchController(
      repository: SearchRepository(service: _SearchService()),
      debounce: Duration.zero,
    );
    controller.updateQuery('vig');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SearchScreen(controller: controller, onOpenAsset: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const Key('codex-search-field')),
    );
    expect(field.controller?.text, 'vig');
    expect(find.text('VIG · Vigilant Demo ETF'), findsOneWidget);
  });
}

const _assignmentId = '00000000-0000-4000-8000-000000000501';
const _assetId = '00000000-0000-4000-8000-000000000502';

void _setReducedMotionPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(
        accessibleNavigation: true,
        disableAnimations: true,
      );
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

void _setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _decodeExactArt(WidgetTester tester, String assetPath) async {
  final context = tester.element(
    find.byKey(const Key('leonidas-ritual-sequence')),
  );
  await tester.runAsync<void>(
    () => precacheImage(AssetImage(assetPath), context),
  );
  await tester.pump();
  await tester.pump();
}

class _ImmediateLeonidasVoice implements LeonidasVoice {
  const _ImmediateLeonidasVoice();

  @override
  Future<bool> speak(String text) async => true;

  @override
  Future<void> stop() async {}
}

class _RecordingLeonidasVoice implements LeonidasVoice {
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

Widget _screenApp({
  required DailyRitualController controller,
  required LeonidasVoice voice,
}) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: DailyRitualScreen(
      controller: controller,
      onOpenCoven: () {},
      onOpenSearch: () {},
      onOpenBriefings: () {},
      onToggleTheme: () {},
      onOpenStarpath: () {},
      leonidasVoice: voice,
      prepareExactMedia: (_) async => true,
    ),
    bottomNavigationBar: NavigationBar(
      destinations: const [
        NavigationDestination(icon: Icon(Icons.auto_awesome), label: 'Ritual'),
        NavigationDestination(icon: Icon(Icons.stars), label: 'Starpath'),
      ],
    ),
  ),
);

class _RitualService implements DailyRitualService {
  _RitualService({
    this.evidenceFailures = 0,
    this.completeFailures = 0,
    this.state = DailyRitualState.completed,
    this.version = 3,
    this.failReveal = false,
    this.hasEvidence = false,
  });

  int evidenceFailures;
  int completeFailures;
  DailyRitualState state;
  int version;
  final bool failReveal;
  final bool hasEvidence;
  int revealCalls = 0;
  int completeCalls = 0;

  @override
  Future<DailyRitual> fetchDaily({DailyRitualMode? mode}) async =>
      _ritual(state: state, version: version, hasEvidence: hasEvidence);

  @override
  Future<DailyRitual> fetchAssignment(String assignmentId) async =>
      _ritual(state: state, version: version, hasEvidence: hasEvidence);

  @override
  Future<List<RitualEvidenceDetail>> fetchEvidence(String assignmentId) async {
    if (evidenceFailures > 0) {
      evidenceFailures -= 1;
      throw const LoadFailure(LoadPhase.retryableFailure);
    }
    return [
      RitualEvidenceDetail(
        claimId: '00000000-0000-4000-8000-000000000503',
        factorLabel: 'Provider-free durability',
        observedAt: DateTime.utc(2026, 8, 25, 12),
        summary: 'The Demo scenario held its fictional range.',
        uncertainty: 'It can reverse.',
        source: RitualEvidenceSource(
          publisher: 'Demo Research Desk',
          title: 'Provider-free evidence note',
          url: Uri.parse('https://example.invalid/evidence'),
          publishedAt: DateTime.utc(2026, 8, 25, 11),
        ),
      ),
    ];
  }

  @override
  Future<RitualHistoryPage> fetchHistory({String? cursor}) async =>
      RitualHistoryPage(
        items: [
          RitualHistoryEntry.fromRitual(
            _ritual(state: state, version: version, hasEvidence: hasEvidence),
          ),
        ],
        nextCursor: null,
        hasMore: false,
      );

  @override
  Future<DailyRitual> reveal(String assignmentId, int expectedVersion) async {
    revealCalls += 1;
    if (failReveal) {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
    state = DailyRitualState.revealed;
    version = expectedVersion + 1;
    return _ritual(state: state, version: version, hasEvidence: hasEvidence);
  }

  @override
  Future<DailyRitual> complete(String assignmentId, int expectedVersion) async {
    completeCalls += 1;
    if (completeFailures > 0) {
      completeFailures -= 1;
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
    state = DailyRitualState.completed;
    version = expectedVersion + 1;
    return _ritual(state: state, version: version, hasEvidence: hasEvidence);
  }
}

class _SingleRitualService extends _RitualService {
  _SingleRitualService(this.ritual)
    : super(state: ritual.state, version: ritual.version);

  final DailyRitual ritual;

  @override
  Future<DailyRitual> fetchDaily({DailyRitualMode? mode}) async => ritual;
}

class _SearchService implements SearchService {
  @override
  Future<SearchPage> search(SearchRequest request) async => SearchPage(
    items: const [
      SearchItem(
        id: _assetId,
        revisionId: '00000000-0000-4000-8000-000000000505',
        kind: SearchKind.asset,
        title: 'Vigilant Demo ETF',
        subtitle: 'Provider-free Demo result',
        symbol: 'VIG',
        isDemo: true,
      ),
    ],
    nextCursor: null,
    hasMore: false,
  );
}

DailyRitual _ritual({
  DailyRitualState state = DailyRitualState.completed,
  int version = 3,
  bool hasEvidence = false,
}) => DailyRitual(
  assignmentId: _assignmentId,
  date: DateTime.utc(2026, 8, 25),
  mode: DailyRitualMode.tarot,
  revision: const RitualRevision(
    id: '00000000-0000-4000-8000-000000000506',
    number: 1,
  ),
  title: 'Direction, not urgency.',
  art: const RitualArt(
    key: 'the_hermit',
    alt: 'The Hermit tarot card: an elder holds a star lantern on a snowy mountain',
  ),
  interpretation: 'Direction is an invitation, not an instruction.',
  guidance: 'Inspect sources before choosing what to research.',
  marketLabel: 'Market-informed Demo evidence',
  ideas: const [
    RitualIdea(
      assetId: _assetId,
      symbol: 'VIG',
      name: 'Vigilant Demo ETF',
      appearanceReason: 'provider-free durability',
      riskSummary: 'The scenario can reverse.',
    ),
  ],
  evidence: hasEvidence
      ? [
          RitualEvidence(
            claimId: '00000000-0000-4000-8000-000000000503',
            factorLabel: 'Provider-free durability',
            observedAt: DateTime.utc(2026, 8, 25, 12),
            summary: 'The Demo scenario held its fictional range.',
            uncertainty: 'It can reverse.',
          ),
        ]
      : const [],
  rowan: const RitualCounsel(
    scriptRevisionId: '00000000-0000-4000-8000-000000000507',
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

DailyRitual _deathRitual() => DailyRitual(
  assignmentId: _assignmentId,
  date: DateTime.utc(2026, 8, 29),
  mode: DailyRitualMode.tarot,
  revision: const RitualRevision(
    id: '00000000-0000-4000-8000-000000000506',
    number: 1,
  ),
  title: 'Death',
  art: const RitualArt(
    key: 'death',
    alt: 'Death tarot card: a skeletal rider advances on a white horse at sunrise',
  ),
  interpretation: 'Death marks a necessary ending: a pattern has run its course, creating room for a cleaner beginning.',
  guidance: 'Name one assumption you are ready to release. Write down the evidence that would show an old thesis no longer fits.',
  marketLabel: 'Tarot reflection',
  ideas: const [],
  evidence: const [],
  rowan: const RitualCounsel(
    scriptRevisionId: '00000000-0000-4000-8000-000000000507',
    surface: 'daily_ritual',
    body: 'Let the ending be information, not catastrophe. Clearing an expired story can make your next question more honest.',
    riskFooter: 'Tarot is a reflection tool, not a prediction or financial recommendation.',
  ),
  version: 3,
  state: DailyRitualState.completed,
  revealedAt: DateTime.utc(2026, 8, 29, 12, 10),
  completedAt: DateTime.utc(2026, 8, 29, 12, 20),
  demo: RitualDisclosure(
    isDemo: false,
    observedAt: DateTime.utc(2026, 8, 29, 12),
    sourceLabel: 'Argus editorial',
    limitations: const ['Educational context only.'],
  ),
);
