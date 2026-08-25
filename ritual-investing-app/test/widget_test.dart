import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ritual_investing_app/app/ritual_investing_app.dart';

import 'support/fixture_services.dart';

void main() {
  testWidgets('opens on the approved daily ritual', (tester) async {
    await tester.pumpWidget(RitualInvestingApp(container: fixtureContainer()));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(find.text('Direction, not urgency.'), findsOneWidget);

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(find.text('Market-informed · reveal the pattern'), findsOneWidget);
    expect(find.text('VIG'), findsOneWidget);
    expect(find.text('Founders’ Coven'), findsOneWidget);
    expect(find.textContaining('Demo market scenario'), findsOneWidget);

    await tester.tap(find.text('Market-informed · reveal the pattern'));
    await tester.pumpAndSettle();
    expect(find.text('Durable dividend momentum'), findsOneWidget);
    expect(
      find.textContaining('Inspect the evidence, compare risks'),
      findsOneWidget,
    );
  });

  testWidgets('primary navigation reaches the Coven', (tester) async {
    await tester.pumpWidget(RitualInvestingApp(container: fixtureContainer()));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Coven').last);
    await tester.pumpAndSettle();

    expect(find.text('Founders’ Coven'), findsOneWidget);
    expect(find.text('DEMO DIRECTORY'), findsOneWidget);
    expect(
      find.textContaining('Effective Aug 20, 2026 · verified Aug 20, 2026'),
      findsWidgets,
    );

    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Seeded examples are fictional'),
      findsOneWidget,
    );
  });

  testWidgets('server-backed Profile controller reaches its screen', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(RitualInvestingApp(container: fixtureContainer()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('You').last);
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Your chamber for Ritual Member'),
      findsOneWidget,
    );
    expect(find.text(r'$1,000.00'), findsOneWidget);
    expect(find.text(r'Demo Portfolio · $1,000.00 cash'), findsOneWidget);
    expect(find.text('Future Mirror'), findsNothing);
    expect(find.text('Link a fictional bank'), findsNothing);
    semantics.dispose();
  });

  testWidgets('theme control switches the application theme', (tester) async {
    await tester.pumpWidget(RitualInvestingApp(container: fixtureContainer()));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    final before = tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .themeMode;

    await tester.tap(find.byKey(const Key('theme-toggle')));
    await tester.pumpAndSettle();

    final after = tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .themeMode;
    expect(before, ThemeMode.system);
    expect(after, isNot(ThemeMode.system));
  });
}
