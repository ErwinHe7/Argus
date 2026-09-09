import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/starpath/application/starpath_controller.dart';
import 'package:ritual_investing_app/features/starpath/application/starpath_narration_controller.dart';
import 'package:ritual_investing_app/features/starpath/data/starpath_repository.dart';
import 'package:ritual_investing_app/features/starpath/domain/investment_constellation.dart';
import 'package:ritual_investing_app/features/starpath/domain/leonidas_story.dart';
import 'package:ritual_investing_app/features/starpath/domain/starpath.dart';
import 'package:ritual_investing_app/features/starpath/presentation/leonidas_story_library.dart';
import 'package:ritual_investing_app/features/starpath/presentation/leonidas_story_screen.dart';
import 'package:ritual_investing_app/features/starpath/presentation/starpath_screen.dart';

import 'leonidas_story_presentation_test.dart' show RecordingVoice, tapVisible;
import 'support/starpath_test_fixture.dart';

void main() {
  setUpAll(() async {
    for (final font in {
      'Inter': 'assets/fonts/Inter-Variable.ttf',
      'LibreBaskerville': 'assets/fonts/LibreBaskerville-Variable.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });
  testWidgets('practice entry requires a current Investment snapshot', (
    tester,
  ) async {
    final service = _PracticeService();
    final controller = _controller(service);
    await controller.load();
    await tester.pumpWidget(
      _app(
        StarpathScreen(
          controller: controller,
          narrationEngineFactory: () => RecordingVoice(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final entry = find.byKey(const Key('starpath-leonidas-stories'));
    expect(entry, findsOneWidget);
    await tester.tap(find.text('Trading'));
    await tester.pumpAndSettle();
    expect(entry, findsNothing);
    await tester.tap(find.text('Investment'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('leonidas-story-library')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    for (final failure in [
      const OfflineException(),
      const StarpathForbidden(),
      const StarpathUnavailable(),
    ]) {
      service.fetchError = failure;
      await controller.load();
      await tester.pumpAndSettle();
      expect(entry, findsNothing);
      service.fetchError = null;
      await controller.load();
      await tester.pumpAndSettle();
      expect(entry, findsOneWidget);
    }
    expect(service.commands, 0);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('four independent chapters keep notes and local state only', (
    tester,
  ) async {
    final service = _PracticeService();
    final controller = _controller(service);
    await controller.load();
    final snapshot = controller.state.snapshot!;
    // These hosted-shaped fixture identities are intentionally unsupported by
    // the inline lesson resolver. Practice must not change their authority.
    expect(
      resolveLeonidasStory(
        snapshot,
        projectInvestmentConstellations(snapshot).first.lessons.first,
      ),
      isNull,
    );
    final preference = StarpathNarrationPreference()..setMuted(true);
    await tester.pumpWidget(
      _app(
        LeonidasStoryLibrary(
          controller: controller,
          narrationPreference: preference,
          narrationEngineFactory: () => RecordingVoice(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Supplementary practice. No recorded progress or knowledge checks.',
      ),
      findsOneWidget,
    );

    for (var chapter = 0; chapter < leonidasStories.length; chapter++) {
      final row = find.byKey(Key('leonidas-library-chapter-${chapter + 1}'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      final screen = tester.widget<LeonidasStoryScreen>(
        find.byType(LeonidasStoryScreen),
      );
      final playback = screen.playback;
      expect(playback.story, same(leonidasStories[chapter]));
      expect(screen.onCheck, isNull);
      await tapVisible(tester, find.byKey(const Key('story-next')));
      expect(playback.index, 1);
      await tapVisible(tester, find.text('Lesson notes'));
      expect(find.byKey(const Key('leonidas-practice-notes')), findsOneWidget);
      for (final label in [
        'Uncertainty',
        'Limitations',
        'Risk context',
        'About the examples',
        'Source',
      ]) {
        await _showNote(tester, find.text(label));
        expect(find.text(label), findsOneWidget);
      }
      await _showNote(
        tester,
        find.byKey(const Key('leonidas-practice-source')),
      );
      final url = tester
          .widget<SelectableText>(find.byType(SelectableText))
          .data!;
      expect(Uri.parse(url).host, 'www.investor.gov');
      expect(find.textContaining('August 31, 2026'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(playback.index, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LeonidasStoryScreen>(find.byType(LeonidasStoryScreen))
            .playback,
        same(playback),
      );
      expect(playback.index, 1);

      while (!playback.atEnd) {
        for (var option = 0; option < playback.beat.options.length; option++) {
          if (playback.beat.interaction != StoryInteraction.choice ||
              playback.beat.options[option].correct) {
            playback.select(option);
          }
        }
        playback.next();
      }
      preference.toggle();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('story-knowledge-check')), findsNothing);
      await tapVisible(tester, find.text('Back to stories'));
      expect(find.byKey(const Key('leonidas-story-library')), findsOneWidget);
    }
    expect(controller.state.snapshot, same(snapshot));
    expect(service.commands, 0);
    await tester.pumpWidget(const SizedBox());
    preference.dispose();
    controller.dispose();
  });

  testWidgets(
    'access loss disposes story voice and removes all practice routes',
    (tester) async {
      final service = _PracticeService();
      final controller = _controller(service);
      await controller.load();
      final preference = StarpathNarrationPreference();
      final voice = _DisposableVoice();
      await tester.pumpWidget(
        _app(
          LeonidasStoryLibrary(
            controller: controller,
            narrationPreference: preference,
            narrationEngineFactory: () => voice,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('leonidas-library-chapter-1')));
      await tester.pumpAndSettle();
      expect(voice.spoken, isNotEmpty);
      await tapVisible(tester, find.text('Lesson notes'));
      expect(voice.stops, greaterThan(0));
      service.fetchError = const StarpathForbidden();
      await controller.load();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('leonidas-practice-unavailable')),
        findsOneWidget,
      );
      expect(find.byType(LeonidasStoryScreen), findsNothing);
      expect(voice.disposed, isTrue);
      expect(service.commands, 0);
      await tester.pumpWidget(const SizedBox());
      preference.dispose();
      controller.dispose();
    },
  );

  for (final size in [const Size(402, 874), const Size(1100, 800)]) {
    testWidgets('chapter list is reachable with 200% text at ${size.width}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      final controller = _controller(_PracticeService());
      await controller.load();
      final preference = StarpathNarrationPreference()..setMuted(true);
      await tester.pumpWidget(
        _app(
          LeonidasStoryLibrary(
            controller: controller,
            narrationPreference: preference,
            narrationEngineFactory: () => RecordingVoice(),
          ),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      if (Platform.environment['LEONIDAS_CAPTURE'] == '1') {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('leonidas-library-capture')),
          );
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = Directory('build/leonidas-story-library-review');
          await output.create(recursive: true);
          await File('${output.path}/library-${size.width.toInt()}-text-2.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      final last = find.byKey(const Key('leonidas-library-chapter-4'));
      await tester.scrollUntilVisible(last, 200);
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      expect(tester.getSemantics(last).label, contains('The Lantern Route'));
      await tester.tap(last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Lesson notes'));
      await _showNote(
        tester,
        find.byKey(const Key('leonidas-practice-source')),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      preference.dispose();
      controller.dispose();
      semantics.dispose();
    });
  }
}

Future<void> _showNote(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('leonidas-practice-notes')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Widget _app(Widget home, {double scale = 1}) => MaterialApp(
  theme: AppTheme.dark,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
    child: RepaintBoundary(
      key: const Key('leonidas-library-capture'),
      child: child!,
    ),
  ),
  home: home,
);

StarpathController _controller(_PracticeService service) => StarpathController(
  repository: StarpathRepository(service: service, cache: MemoryReadCache()),
  createKey: () => 'practice-test',
);

class _PracticeService extends StarpathFixtureService {
  _PracticeService()
    : super(snapshot: starpathFixtureSnapshot(currentOrdinal: 1));
  Object? fetchError;
  int commands = 0;
  @override
  Future<StarpathSnapshot> fetch() async {
    if (fetchError case final error?) throw error;
    return snapshot;
  }

  @override
  Future<StarpathSnapshot> start({required String idempotencyKey}) async {
    commands++;
    return snapshot;
  }

  @override
  Future<StarpathSnapshot> answer({
    required String idempotencyKey,
    required int version,
    required StarpathAnswerCommand command,
  }) async {
    commands++;
    return snapshot;
  }

  @override
  Future<StarpathSnapshot> skipRecall({
    required String idempotencyKey,
    required int version,
    required String sessionId,
  }) async {
    commands++;
    return snapshot;
  }
}

class _DisposableVoice extends RecordingVoice {
  bool disposed = false;
  @override
  void dispose() => disposed = true;
}
