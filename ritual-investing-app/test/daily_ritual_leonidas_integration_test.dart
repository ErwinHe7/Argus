import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/ritual_investing_app.dart';

import 'support/fixture_services.dart';

void main() {
  testWidgets(
    'Daily Ritual uses the Leonidas sequence and keeps evidence one gesture away',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        RitualInvestingApp(container: fixtureContainer()),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('leonidas-ritual-sequence')), findsOneWidget);
      expect(find.byKey(const Key('leonidas-close-up')), findsOneWidget);
      expect(find.byKey(const Key('leonidas-card-front')), findsOneWidget);
      expect(find.text("TODAY'S REFLECTION"), findsNothing);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('leonidas-evidence')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ritual-evidence-sheet')), findsOneWidget);
      expect(
        find.textContaining('research cues, not predictions'),
        findsOneWidget,
      );
    },
  );
}
