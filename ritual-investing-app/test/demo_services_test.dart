import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/bootstrap/app_runtime.dart';
import 'package:ritual_investing_app/demo/demo_services.dart';
import 'package:ritual_investing_app/features/grimoires/domain/model.dart';

void main() {
  test('demo services bootstrap the curated member scope in memory', () async {
    final demo = await DemoServices.bootstrap();
    addTearDown(demo.dispose);

    expect(demo.runtime.entryGate, MemberEntryGate.member);
    expect(demo.runtime.presentationPolicy, MemberPresentationPolicy.demo);
    expect(demo.runtime.hasAssetCodex, isTrue);
    expect(demo.runtime.hasGrimoires, isTrue);
    expect(demo.runtime.hasCircles, isFalse);
    expect(demo.runtime.hasSimulatedInvesting, isFalse);
    expect(demo.runtime.hasPrivacyControls, isFalse);
    expect(demo.runtime.dailyRitualController.state.value, isNotNull);
  });

  test('saving a Grimoire is memory-only and a fresh demo resets it', () async {
    const grimoireId = '00000000-0000-4000-8000-000000000541';
    final first = await DemoServices.bootstrap();
    addTearDown(first.dispose);
    final controller = first.runtime.createGrimoireController(grimoireId);
    addTearDown(controller.dispose);

    await controller.load();
    expect(controller.state.value?.saved, isFalse);
    await controller.toggleSaved();
    expect(controller.state.value?.saved, isTrue);
    expect(controller.savePhase, GrimoireSavePhase.saved);

    final reset = await DemoServices.bootstrap();
    addTearDown(reset.dispose);
    final resetController = reset.runtime.createGrimoireController(grimoireId);
    addTearDown(resetController.dispose);
    await resetController.load();
    expect(resetController.state.value?.saved, isFalse);
  });
}
