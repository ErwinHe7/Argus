import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/demo/demo_bootstrap.dart';
import 'package:ritual_investing_app/demo/demo_services.dart';

void main() {
  testWidgets(
    'demo enters the painted member shell and emits compatible ready events',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final services = await DemoServices.bootstrap();
      addTearDown(services.dispose);
      final channel = RecordingDemoFrameChannel();

      await tester.pumpWidget(
        DemoRitualInvestingApp(
          runtime: services.runtime,
          frameIdentity: const DemoFrameIdentity(
            environment: DemoEnvironment.production,
            attemptId: 'attempt-widget-1',
          ),
          frameChannel: channel,
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('app-shell-scaffold')), findsOneWidget);
      expect(find.text('YOUR DAILY SIGNAL'), findsOneWidget);
      expect(find.text('Welcome'), findsNothing);
      expect(find.textContaining('Sign in'), findsNothing);
      expect(channel.events.map((event) => event.protocolVersion), [2, 1]);
      expect(
        channel.events.every((event) => event.attemptId == 'attempt-widget-1'),
        isTrue,
      );
      expect(channel.events.map((event) => event.targetOrigin).toSet(), {
        'https://just-build-this.app',
      });
    },
  );

  testWidgets(
    'demo exposes exactly four curated branches and read-only You controls',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final services = await DemoServices.bootstrap();
      addTearDown(services.dispose);
      await tester.pumpWidget(
        DemoRitualInvestingApp(
          runtime: services.runtime,
          frameIdentity: const DemoFrameIdentity(
            environment: DemoEnvironment.beta,
            attemptId: 'attempt-widget-2',
          ),
          frameChannel: RecordingDemoFrameChannel(),
        ),
      );
      await tester.pump();

      for (final label in ['Ritual', 'Discover', 'Coven', 'You']) {
        expect(find.text(label), findsWidgets);
      }

      await tester.tap(find.text('You').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('you-portfolio')), findsOneWidget);
      expect(find.byKey(const Key('you-investing')), findsNothing);
      expect(find.byKey(const Key('you-ritual-preferences')), findsNothing);
      expect(find.byKey(const Key('you-astrology')), findsNothing);
      expect(find.byKey(const Key('you-account')), findsNothing);
      expect(find.byKey(const Key('you-privacy')), findsNothing);
      expect(find.byKey(const Key('you-notifications')), findsNothing);
      expect(find.byKey(const Key('you-membership')), findsNothing);
    },
  );

  testWidgets('demo artwork uses dependency-safe package asset keys', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final services = await DemoServices.bootstrap();
    addTearDown(services.dispose);
    await tester.pumpWidget(
      DemoRitualInvestingApp(
        runtime: services.runtime,
        frameIdentity: const DemoFrameIdentity(
          environment: DemoEnvironment.production,
          attemptId: 'asset-key-proof',
        ),
        frameChannel: RecordingDemoFrameChannel(),
      ),
    );
    await tester.pump();

    AssetImage assetFor(String name) => tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .whereType<AssetImage>()
        .firstWhere((image) => image.assetName == name);

    final compass = assetFor('assets/images/the-compass.png');
    expect(compass.package, 'ritual_investing_app');
    expect(
      compass.keyName,
      'packages/ritual_investing_app/assets/images/the-compass.png',
    );
    final compassBytes = await rootBundle.load(compass.keyName);
    expect(compassBytes.lengthInBytes, greaterThan(100000));

    await tester.drag(
      find.byKey(const PageStorageKey('daily-ritual-scroll')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    final persona = assetFor('assets/images/persona-triptych.png');
    expect(persona.package, 'ritual_investing_app');
    expect(
      persona.keyName,
      'packages/ritual_investing_app/assets/images/persona-triptych.png',
    );
    final personaBytes = await rootBundle.load(persona.keyName);
    expect(personaBytes.lengthInBytes, greaterThan(100000));
  });

  testWidgets('startup failure emits only sanitized compatible error events', (
    tester,
  ) async {
    final channel = RecordingDemoFrameChannel();
    await tester.pumpWidget(
      DemoStartupFailureApp(
        frameIdentity: const DemoFrameIdentity(
          environment: DemoEnvironment.production,
          attemptId: 'attempt-error-1',
        ),
        frameChannel: channel,
      ),
    );
    await tester.pump();

    expect(find.text('The Demo could not start.'), findsOneWidget);
    expect(channel.events.map((event) => event.type), [
      DemoFrameEventType.error,
      DemoFrameEventType.error,
    ]);
    expect(channel.events.every((event) => event.detail == null), isTrue);
    expect(channel.events.map((event) => event.targetOrigin).toSet(), {
      'https://just-build-this.app',
    });
  });

  test('frame events map environments to exact landing origins', () {
    const production = DemoFrameEvent(
      type: DemoFrameEventType.ready,
      protocolVersion: demoCurrentProtocolVersion,
      environment: DemoEnvironment.production,
      attemptId: 'production-attempt',
    );
    const beta = DemoFrameEvent(
      type: DemoFrameEventType.ready,
      protocolVersion: demoCurrentProtocolVersion,
      environment: DemoEnvironment.beta,
      attemptId: 'beta-attempt',
    );

    expect(production.targetOrigin, 'https://just-build-this.app');
    expect(beta.targetOrigin, 'https://beta.just-build-this.app');
    expect(production.targetOrigin, isNot('*'));
    expect(beta.targetOrigin, isNot('*'));
  });
}
