import 'package:flutter/material.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/features/starpath/application/starpath_controller.dart';
import 'package:ritual_investing_app/features/starpath/presentation/starpath_screen.dart';

import 'support/starpath_test_fixture.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = starpathFixtureController();
  await controller.load();
  runApp(_StarpathPreview(controller: controller));
}

class _StarpathPreview extends StatelessWidget {
  const _StarpathPreview({required this.controller});

  final StarpathController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Starpath · Local Preview',
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    home: Banner(
      message: 'LOCAL PREVIEW',
      location: BannerLocation.topEnd,
      child: StarpathScreen(controller: controller),
    ),
  );
}
