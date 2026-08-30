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

    await tester.scrollUntilVisible(
      find.textContaining('Demo market scenario'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Demo market scenario'), findsOneWidget);

    await tester.tap(find.text('Market-informed · reveal the pattern'));
    await tester.pumpAndSettle();
    expect(find.text('Durable dividend momentum'), findsOneWidget);
    expect(
      find.textContaining('Inspect the evidence, compare risks'),
      findsWidgets,
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
    expect(find.bySemanticsLabel('You, Ritual Member'), findsOneWidget);
    expect(find.text('Demo Portfolio'), findsNothing);
    expect(find.text('Investing profile'), findsOneWidget);
    expect(find.text('Ritual and appearance'), findsOneWidget);
    expect(find.text('Future Mirror'), findsNothing);
    expect(find.text('Link a fictional bank'), findsNothing);
    semantics.dispose();
  });

  testWidgets('theme control saves and applies server authority', (
    tester,
  ) async {
    await tester.pumpWidget(RitualInvestingApp(container: fixtureContainer()));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    final before = tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .themeMode;

    await tester.tap(find.byKey(const Key('theme-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Ritual and appearance'), findsOneWidget);
    await tester.tap(find.byKey(const Key('theme-dark')));
    await tester.scrollUntilVisible(
      find.byKey(const Key('preferences-save')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('preferences-save')));
    await tester.pumpAndSettle();

    final after = tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .themeMode;
    expect(before, ThemeMode.system);
    expect(after, ThemeMode.dark);
  });
}
