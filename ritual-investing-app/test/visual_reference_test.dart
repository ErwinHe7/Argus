import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ritual_investing_app/app/ritual_investing_app.dart';
import 'package:ritual_investing_app/core/navigation/member_routes.dart';

import 'support/fixture_services.dart';

void main() {
  testWidgets('captures the daily ritual in both approved atmospheres', (
    tester,
  ) async {
    await _loadFont('Inter', 'assets/fonts/Inter-Variable.ttf');
    await _loadFont(
      'LibreBaskerville',
      'assets/fonts/LibreBaskerville-Variable.ttf',
    );
    await _loadFont('MaterialIcons', 'fonts/MaterialIcons-Regular.otf');
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(RitualInvestingApp(container: fixtureContainer()));
    await tester.runAsync(() async {
      final context = tester.element(find.byType(Scaffold).first);
      await Future.wait([
        precacheImage(
          const AssetImage(
            'assets/images/tarot/modern-rider-waite/major/04-the-emperor.webp',
          ),
          context,
        ),
        precacheImage(
          const AssetImage(
            'assets/images/persona-triptych.png',
          ),
          context,
        ),
      ]);
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // Warm both theme frames before recording a baseline so the first golden
    // cannot race the initial image decode.
    await _setAuthoritativeTheme(tester, 'dark');
    await _setAuthoritativeTheme(tester, 'light');

    final dailyRitualScrollable = find.descendant(
      of: find.byKey(const PageStorageKey('daily-ritual-scroll')),
      matching: find.byType(Scrollable),
    );
    expect(dailyRitualScrollable, findsOneWidget);
    tester.state<ScrollableState>(dailyRitualScrollable).position.jumpTo(0);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(dailyRitualScrollable).position.pixels,
      0,
    );

    await expectLater(
      find.byKey(const Key('app-shell-scaffold')),
      matchesGoldenFile('goldens/daily_ritual_light.png'),
    );

    await _setAuthoritativeTheme(tester, 'dark');

    tester.state<ScrollableState>(dailyRitualScrollable).position.jumpTo(0);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('app-shell-scaffold')),
      matchesGoldenFile('goldens/daily_ritual_dark.png'),
    );
  });

  testWidgets(
    'ritual hierarchy leads into adjacent provider-free Demo surfaces',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        RitualInvestingApp(container: fixtureContainer(includeU7: true)),
      );
      await tester.pumpAndSettle();

      final art = find.bySemanticsLabel(
        'The Emperor tarot card: a ruler sits on a ram-carved throne before mountains',
      );
      final interpretation = find.text('Direction, not urgency.');
      expect(art, findsOneWidget);
      expect(interpretation, findsOneWidget);
      expect(
        tester.getTopLeft(art).dy,
        lessThan(tester.getTopLeft(interpretation).dy),
      );
      expect(find.text('YOUR DAILY SIGNAL'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.textContaining('Demo market scenario'),
        280,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Demo market scenario'), findsOneWidget);
      expect(find.text('Market-informed · reveal the pattern'), findsOneWidget);

      var router = GoRouter.of(
        tester.element(find.byKey(const Key('app-shell-scaffold'))),
      );
      router.go(MemberRoutes.portfolio.location('fixture-portfolio'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Provider-free Demo · No real money moves'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Demo experience; no real money moves'),
        findsWidgets,
      );
      expect(find.textContaining('No real money moves'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        RitualInvestingApp(container: fixtureContainer(includeU10: true)),
      );
      await tester.pumpAndSettle();
      router = GoRouter.of(
        tester.element(find.byKey(const Key('app-shell-scaffold'))),
      );
      router.go(MemberRoutes.youMembershipPath);
      await tester.pumpAndSettle();
      expect(find.text('Demo membership'), findsOneWidget);
      expect(find.textContaining('no card or bank'), findsOneWidget);
      expect(find.textContaining('no payment provider'), findsOneWidget);
      semantics.dispose();
    },
  );
}

Future<void> _setAuthoritativeTheme(WidgetTester tester, String theme) async {
  await tester.tap(find.byKey(const Key('theme-toggle')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('theme-$theme')));
  await tester.scrollUntilVisible(
    find.byKey(const Key('preferences-save')),
    300,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.byKey(const Key('preferences-save')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ritual').last);
  await tester.pumpAndSettle();
}

Future<void> _loadFont(String family, String asset) async {
  final loader = FontLoader(family)..addFont(rootBundle.load(asset));
  await loader.load();
}
