import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/ritual_investing_app.dart';

import 'support/fixture_services.dart';

void main() {
  testWidgets(
    'restored Daily Ritual keeps Evidence and Starpath in the shell',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        RitualInvestingApp(container: fixtureContainer()),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('daily-ritual-immersive')), findsNothing);
      expect(find.byKey(const Key('leonidas-ritual-sequence')), findsOneWidget);
      final ritualContext = tester.element(
        find.byKey(const Key('leonidas-ritual-sequence')),
      );
      await tester.runAsync<void>(
        () => precacheImage(
          const AssetImage(
            'assets/images/tarot/modern-rider-waite/major/04-the-emperor.webp',
          ),
          ritualContext,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('leonidas-ritual-sequence')), findsOneWidget);
      expect(find.byKey(const Key('daily-ritual-immersive')), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byKey(const Key('leonidas-portrait-focus')), findsOneWidget);
      expect(find.byKey(const Key('leonidas-card-front')), findsOneWidget);
      expect(find.text("TODAY'S REFLECTION"), findsNothing);
      expect(find.byKey(const Key('ritual-history')), findsNothing);

      await tester.tap(find.byKey(const Key('leonidas-evidence')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ritual-evidence-sheet')), findsOneWidget);
      expect(find.text('Observation'), findsOneWidget);
      expect(find.text('Summary'), findsOneWidget);
      expect(find.textContaining('durable dividend momentum'), findsWidgets);

      await tester.tap(find.byKey(const Key('ritual-evidence-done')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('daily-ritual-immersive')), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byKey(const Key('leonidas-evidence')), findsOneWidget);

      await tester.tap(find.byKey(const Key('leonidas-starpath')));
      await tester.pumpAndSettle();
      expect(find.text('Walk the Stars'), findsWidgets);
    },
  );
}
