import 'package:flutter/material.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/starpath/application/starpath_controller.dart';
import 'package:ritual_investing_app/features/starpath/application/starpath_narration_controller.dart';
import 'package:ritual_investing_app/features/starpath/data/starpath_repository.dart';
import 'package:ritual_investing_app/features/starpath/domain/investment_constellation.dart';
import 'package:ritual_investing_app/features/starpath/presentation/starpath_lesson_screen.dart';

import 'support/leonidas_story_fixture.dart';
import 'support/starpath_test_fixture.dart';

/// Isolated, provider-free visual review of the real Starpath route integration.
/// Test lesson notes and checks are fixtures and never publish member progress.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = StarpathController(
    repository: StarpathRepository(
      service: StarpathFixtureService(snapshot: pilotSnapshot()),
      cache: MemoryReadCache(),
    ),
    createKey: () => 'story-preview',
  );
  await controller.load();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Leonidas · Story preview',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      builder: (context, child) => Banner(
        message: 'LOCAL PREVIEW',
        location: BannerLocation.bottomStart,
        child: child!,
      ),
      home: StarpathLessonScreen(
        controller: controller,
        constellation: projectInvestmentConstellations(
          controller.state.snapshot!,
        ).first,
        readOnly: true,
        preview: true,
        narrationPreference: StarpathNarrationPreference(),
      ),
    ),
  );
}
