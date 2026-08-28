import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/demo_bootstrap.dart';
import '../lib/demo_services.dart';

void main() {
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
          environment: DemoEnvironment.production,
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
