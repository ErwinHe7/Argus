import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/demo_bootstrap.dart';
import '../lib/demo_services.dart';

void main() {
  test('frame identity accepts only prod and staging protocol values', () {
    expect(
      DemoFrameIdentity.fromUri(
        Uri.parse('https://demo.just-build-this.app/?environment=prod'),
      ).environment,
      DemoEnvironment.prod,
    );
    expect(
      DemoFrameIdentity.fromUri(
        Uri.parse(
          'https://demo-staging.just-build-this.app/?environment=staging',
        ),
      ).environment,
      DemoEnvironment.staging,
    );
    expect(
      DemoFrameIdentity.fromUri(Uri.parse('https://demo.just-build-this.app/'))
          .environment,
      DemoEnvironment.prod,
    );
    for (final environment in const ['beta', 'production', 'unknown']) {
      expect(
        () => DemoFrameIdentity.fromUri(
          Uri.parse('https://demo.example/?environment=$environment'),
        ),
        throwsFormatException,
        reason: environment,
      );
    }
  });

  testWidgets('curated shell resets document-owned mutations', (tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final first = await DemoServices.bootstrap();
    final firstChannel = RecordingDemoFrameChannel();
    await tester.pumpWidget(
      DemoRitualInvestingApp(
        runtime: first.runtime,
        frameIdentity: const DemoFrameIdentity(
          environment: DemoEnvironment.prod,
          attemptId: 'test-first',
        ),
        frameChannel: firstChannel,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('YOUR DAILY SIGNAL'), findsOneWidget);
    expect(firstChannel.events, hasLength(2));
    final firstRepository = first.runtime.featureScope!.grimoireRepository!;
    final initial = (await firstRepository.load(_grimoireId)).value;
    expect(initial.saved, isFalse);
    final saved = await firstRepository.setSaved(initial, true);
    expect(saved.value.saved, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    first.dispose();

    final second = await DemoServices.bootstrap();
    addTearDown(second.dispose);
    final reset = (await second.runtime.featureScope!.grimoireRepository!.load(
      _grimoireId,
    )).value;
    expect(reset.saved, isFalse);
  });
}

const _grimoireId = '00000000-0000-4000-8000-000000000541';
