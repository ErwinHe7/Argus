import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../lib/main.dart' as demo_app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('curated browser shell navigates and resets its local mutation', (
    tester,
  ) async {
    await demo_app.main();
    await tester.pumpAndSettle();

    expect(find.text('YOUR DAILY SIGNAL'), findsOneWidget);
    await tester.tap(find.text('Discover').last);
    await tester.pumpAndSettle();
    expect(find.text('Quiet Power Grimoire'), findsOneWidget);

    await tester.tap(find.text('Quiet Power Grimoire'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('grimoire-save')), findsOneWidget);
    expect(find.text('Save Grimoire'), findsOneWidget);
    await tester.tap(find.byKey(const Key('grimoire-save')));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);

    // Replacing the document-owned app creates a fresh runtime and fixtures.
    await demo_app.main();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discover').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quiet Power Grimoire'));
    await tester.pumpAndSettle();
    expect(find.text('Save Grimoire'), findsOneWidget);
  });
}
