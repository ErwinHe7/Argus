import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final outputDirectory = Platform.environment['RITUAL_SCREENSHOT_DIR'];
  if (outputDirectory == null || outputDirectory.isEmpty) {
    throw StateError('RITUAL_SCREENSHOT_DIR must name the evidence directory.');
  }

  await integrationDriver(
    onScreenshot: (name, bytes, [arguments]) async {
      final file = File('$outputDirectory/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return true;
    },
  );
}
