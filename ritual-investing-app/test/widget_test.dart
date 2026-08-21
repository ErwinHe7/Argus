import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ritual_investing_app/app/ritual_investing_app.dart';

void main() {
  testWidgets('opens on the approved daily ritual', (tester) async {
    await tester.pumpWidget(const RitualInvestingApp());

    expect(find.text('Direction, not urgency.'), findsOneWidget);

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(find.text('Market-informed · reveal the pattern'), findsOneWidget);
    expect(find.text('Founders’ Coven'), findsOneWidget);
    expect(find.textContaining('Demo market scenario'), findsOneWidget);
  });

  testWidgets('primary navigation reaches the Coven', (tester) async {
    await tester.pumpWidget(const RitualInvestingApp());

    await tester.tap(find.text('Coven').last);
    await tester.pumpAndSettle();

    expect(find.text('Founders’ Coven'), findsOneWidget);
    expect(find.text('DEMO DIRECTORY'), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Seeded examples are fictional'),
      findsOneWidget,
    );
  });

  testWidgets('theme control switches the application theme', (tester) async {
    await tester.pumpWidget(const RitualInvestingApp());
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
