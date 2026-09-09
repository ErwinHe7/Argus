import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/features/starpath/application/leonidas_story_playback.dart';
import 'package:ritual_investing_app/features/starpath/application/starpath_narration_controller.dart';
import 'package:ritual_investing_app/features/starpath/domain/leonidas_story.dart';
import 'package:ritual_investing_app/features/starpath/presentation/leonidas_story_screen.dart';

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
  testWidgets(
    'choices, notes, mute, replay and lifecycle stop the active line',
    (tester) async {
      final voice = RecordingVoice();
      final preference = StarpathNarrationPreference();
      final playback = LeonidasStoryPlayback(leonidasStories.first);
      var notes = 0;
      await tester.pumpWidget(
        app(
          playback,
          voice,
          preference,
          onNotes: () async {
            notes++;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(voice.spoken.last, playback.beat.line);
      await tapVisible(tester, find.byKey(const Key('story-next')));
      expect(playback.index, 1);
      expect(voice.stops, greaterThan(0));
      await tapVisible(tester, find.byKey(const Key('story-next')));
      expect(playback.index, 2);
      await tapVisible(tester, find.byKey(const Key('story-option-0')));
      expect(voice.spoken.last, playback.feedback);
      expect(playback.canAdvance, isFalse);
      await tapVisible(tester, find.byKey(const Key('story-option-1')));
      expect(playback.canAdvance, isTrue);
      await tapVisible(tester, find.byKey(const Key('story-next')));
      await tapVisible(tester, find.byKey(const Key('story-option-1')));
      expect(playback.retry, isTrue);
      expect(playback.canAdvance, isFalse);
      await tapVisible(tester, find.byKey(const Key('story-option-0')));
      expect(playback.canAdvance, isTrue);
      await tapVisible(tester, find.text('Lesson notes'));
      expect(notes, 1);
      final spoken = voice.spoken.length;
      preference.setMuted(true);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('story-next')));
      expect(voice.spoken.length, spoken);
      preference.setMuted(false);
      await tester.pumpAndSettle();
      final stops = voice.stops;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(voice.stops, greaterThan(stops));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.tap(find.byTooltip('Story options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replay chapter'));
      await tester.pumpAndSettle();
      expect(playback.index, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      preference.dispose();
    },
  );

  for (final size in [const Size(402, 874), const Size(1100, 800)]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('readable ${size.width} dark=$dark text=$scale', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final semantics = tester.ensureSemantics();
          final playback = LeonidasStoryPlayback(leonidasStories[3])..next();
          final preference = StarpathNarrationPreference()..setMuted(true);
          await tester.pumpWidget(
            app(
              playback,
              RecordingVoice(),
              preference,
              dark: dark,
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.bySemanticsLabel('Leonidas in The observatory map room'),
            findsOneWidget,
          );
          for (var index = 0; index < 3; index++) {
            await tapVisible(tester, find.byKey(Key('story-option-$index')));
          }
          expect(playback.canAdvance, isTrue);
          await tapVisible(tester, find.byKey(const Key('story-next')));
          expect(playback.index, 2);
          expect(tester.takeException(), isNull);
          // Optional review artifacts, not committed golden baselines.
          if (Platform.environment['LEONIDAS_CAPTURE'] == '1' && scale == 1) {
            await tester.runAsync(() async {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const Key('capture')),
              );
              final image = await boundary.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                'build/leonidas-review/${size.width.toInt()}-${dark ? 'dark' : 'light'}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          semantics.dispose();
          await tester.pumpWidget(const SizedBox());
          preference.dispose();
        });
      }
    }
  }

  testWidgets('unavailable speech leaves chapter controls usable', (
    tester,
  ) async {
    final playback = LeonidasStoryPlayback(leonidasStories.first);
    final preference = StarpathNarrationPreference();
    await tester.pumpWidget(
      app(playback, RecordingVoice(available: false), preference),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('story-next')));
    expect(playback.index, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    preference.dispose();
  });

  testWidgets('garden camera respects pause, lifecycle and hidden routes', (
    tester,
  ) async {
    final preference = StarpathNarrationPreference()..setMuted(true);
    final playback = LeonidasStoryPlayback(leonidasStories.first);
    final bundle = GardenAssetBundle(
      await rootBundle.load('assets/images/brand/leo-lion.png'),
    );
    Widget garden({bool tickerEnabled = true}) => app(
      playback,
      RecordingVoice(),
      preference,
      assets: bundle,
      reducedMotion: false,
      tickerEnabled: tickerEnabled,
    );
    await tester.pumpWidget(garden());
    await tester.runAsync(
      () => precacheImage(
        AssetImage(GardenAssetBundle.path, bundle: bundle),
        tester.element(find.byKey(const Key('leonidas-garden-camera'))),
      ),
    );
    await tester.pump();
    await tester.pump();
    final before = gardenScale(tester);
    await tester.pump(const Duration(seconds: 4));
    expect(gardenScale(tester), greaterThan(before));
    expect(gardenScale(tester), inInclusiveRange(1.015, 1.04));
    final pause = find.byTooltip('Pause scene motion');
    expect(tester.getSize(pause), const Size(48, 48));
    await tester.tap(pause);
    await tester.pump();
    final paused = gardenScale(tester);
    await tester.pump(const Duration(seconds: 4));
    expect(gardenScale(tester), paused);
    await tester.tap(find.byTooltip('Resume scene motion'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(gardenScale(tester), isNot(paused));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final background = gardenScale(tester);
    await tester.pump(const Duration(seconds: 4));
    expect(gardenScale(tester), background);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(garden(tickerEnabled: false));
    final hidden = gardenScale(tester);
    await tester.pump(const Duration(seconds: 4));
    expect(gardenScale(tester), hidden);
    await tester.pumpWidget(const SizedBox());
    preference.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('garden is still with reduced motion and preserves its label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final preference = StarpathNarrationPreference()..setMuted(true);
    final bundle = GardenAssetBundle(
      await rootBundle.load('assets/images/brand/leo-lion.png'),
    );
    await tester.pumpWidget(
      app(
        LeonidasStoryPlayback(leonidasStories.first),
        RecordingVoice(),
        preference,
        assets: bundle,
      ),
    );
    await tester.pumpAndSettle();
    final still = gardenScale(tester);
    await tester.pump(const Duration(seconds: 20));
    expect(gardenScale(tester), still);
    expect(find.byKey(const Key('leonidas-scene-motion')), findsNothing);
    expect(
      find.bySemanticsLabel('Leonidas in Observatory courtyard'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    preference.dispose();
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('garden stage fits a 390px phone with double-size text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preference = StarpathNarrationPreference()..setMuted(true);
    final bundle = GardenAssetBundle(
      await rootBundle.load('assets/images/brand/leo-lion.png'),
    );
    final playback = LeonidasStoryPlayback(leonidasStories.first);
    await tester.pumpWidget(
      app(
        playback,
        RecordingVoice(),
        preference,
        scale: 2,
        assets: bundle,
        reducedMotion: false,
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        AssetImage(GardenAssetBundle.path, bundle: bundle),
        tester.element(find.byKey(const Key('leonidas-garden-camera'))),
      ),
    );
    await tester.pump();
    await tester.pump();
    final pause = find.byTooltip('Pause scene motion');
    expect(tester.getSize(pause), const Size(48, 48));
    final frame = find.byKey(const Key('leonidas-speaker-portrait'));
    final inset = tester.getRect(frame);
    final scene = tester.getRect(
      find.byKey(const Key('leonidas-garden-camera')),
    );
    expect(scene.contains(inset.topLeft), isTrue);
    expect(scene.contains(inset.bottomRight), isTrue);
    expect(inset.contains(scene.center), isFalse);
    expect(inset.overlaps(tester.getRect(pause)), isFalse);
    final caption = tester.renderObject<RenderParagraph>(
      find.descendant(of: frame, matching: find.text('Leonidas')),
    );
    expect(caption.didExceedMaxLines, isFalse);
    await tester.tap(pause);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('story-next')));
    expect(playback.index, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    preference.dispose();
  });

  testWidgets('missing garden art falls back to the canonical portrait', (
    tester,
  ) async {
    final preference = StarpathNarrationPreference()..setMuted(true);
    final playback = LeonidasStoryPlayback(leonidasStories.first);
    await tester.pumpWidget(
      app(
        playback,
        RecordingVoice(),
        preference,
        assets: GardenAssetBundle(null),
        reducedMotion: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('leonidas-garden-camera')), findsNothing);
    expect(find.byKey(const ValueKey('warm-reassurance')), findsOneWidget);
    expect(find.byKey(const Key('leonidas-scene-motion')), findsNothing);
    await tapVisible(tester, find.byKey(const Key('story-next')));
    expect(playback.index, 1);
    await tester.pumpWidget(const SizedBox());
    preference.dispose();
    expect(tester.takeException(), isNull);
  });
}

double gardenScale(WidgetTester tester) => tester
    .widget<Transform>(find.byKey(const Key('leonidas-garden-camera')))
    .transform
    .entry(0, 0);

class GardenAssetBundle extends CachingAssetBundle {
  GardenAssetBundle(this.scene);
  static const path = 'assets/images/leonidas/leonidas-garden-blender-v1.png';
  final ByteData? scene;

  @override
  Future<ByteData> load(String key) {
    if (key != path) return rootBundle.load(key);
    if (scene case final bytes?) return Future.value(bytes);
    return Future.error(FlutterError('Garden scene unavailable for this test'));
  }
}

Widget app(
  LeonidasStoryPlayback playback,
  RecordingVoice voice,
  StarpathNarrationPreference preference, {
  bool dark = false,
  double scale = 1,
  bool reducedMotion = true,
  bool tickerEnabled = true,
  AssetBundle? assets,
  Future<void> Function()? onNotes,
}) => MaterialApp(
  theme: dark ? AppTheme.dark : AppTheme.light,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        disableAnimations: reducedMotion,
      ),
      child: TickerMode(
        enabled: tickerEnabled,
        child: DefaultAssetBundle(
          bundle: assets ?? rootBundle,
          child: RepaintBoundary(
            key: const Key('capture'),
            child: LeonidasStoryScreen(
              playback: playback,
              narrationPreference: preference,
              narrationEngineFactory: () => voice,
              onNotes: onNotes ?? () async {},
              onContinue: () async {},
              continueLabel: 'Next chapter',
            ),
          ),
        ),
      ),
    ),
  ),
);

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    160,
    scrollable: find.descendant(
      of: find.byKey(const Key('leonidas-story-dialogue')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class RecordingVoice implements StarpathNarrationEngine {
  RecordingVoice({this.available = true});
  final bool available;
  final spoken = <String>[];
  int stops = 0;
  VoidCallback? start;
  VoidCallback? cancel;
  @override
  void bind({
    required VoidCallback onStart,
    required VoidCallback onComplete,
    required VoidCallback onCancel,
    required VoidCallback onError,
  }) {
    start = onStart;
    cancel = onCancel;
  }

  @override
  Future<bool> configure() async => available;
  @override
  Future<bool> speak(String text) async {
    spoken.add(text);
    start?.call();
    return true;
  }

  @override
  Future<void> stop() async {
    stops++;
    cancel?.call();
  }

  @override
  void dispose() {}
}
