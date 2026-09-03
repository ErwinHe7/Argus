import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ritual_investing_app/app/ritual_investing_app.dart';

import 'support/fixture_services.dart';

void main() {
  testWidgets('restores the approved daily ritual in place', (tester) async {
    await tester.pumpWidget(RitualInvestingApp(container: fixtureContainer()));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('leonidas-ritual-sequence')), findsOneWidget);
    expect(find.byKey(const Key('daily-ritual-immersive')), findsNothing);

    final context = tester.element(
      find.byKey(const Key('leonidas-ritual-sequence')),
    );
    await tester.runAsync<void>(
      () => precacheImage(
        const AssetImage(
          'assets/images/tarot/modern-rider-waite/major/04-the-emperor.webp',
        ),
        context,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily-ritual-immersive')), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Direction, not urgency.'), findsOneWidget);
    expect(find.byKey(const Key('leonidas-evidence')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('leonidas-evidence')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('leonidas-evidence')));
    await tester.pumpAndSettle();
    expect(find.text('Durable dividend momentum'), findsOneWidget);
    expect(find.byKey(const Key('ritual-evidence-done')), findsOneWidget);
  });

  testWidgets('primary navigation reaches the Coven', (tester) async {
    await tester.pumpWidget(RitualInvestingApp(container: fixtureContainer()));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Coven').last);
    await tester.pumpAndSettle();

    expect(find.text('Founders’ Coven'), findsOneWidget);
    expect(find.text('RESEARCH DIRECTORY'), findsOneWidget);
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
    expect(find.text('Gospel and appearance'), findsOneWidget);
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
    expect(find.text('Gospel and appearance'), findsOneWidget);
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
