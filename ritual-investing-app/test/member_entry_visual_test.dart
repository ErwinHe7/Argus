import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/features/auth/presentation/member_sign_in_screen.dart';
import 'package:ritual_investing_app/features/onboarding/application/onboarding_controller.dart';
import 'package:ritual_investing_app/features/onboarding/domain/onboarding_draft.dart';
import 'package:ritual_investing_app/features/onboarding/presentation/onboarding_flow.dart';

void main() {
  setUpAll(() async {
    await _loadFont('Inter', 'assets/fonts/Inter-Variable.ttf');
    await _loadFont(
      'LibreBaskerville',
      'assets/fonts/LibreBaskerville-Variable.ttf',
    );
    await _loadFont('MaterialIcons', 'fonts/MaterialIcons-Regular.otf');
  });

  for (final brightness in Brightness.values) {
    testWidgets('captures member entry in ${brightness.name}', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: brightness == Brightness.light
              ? AppTheme.light
              : AppTheme.dark,
          home: WelcomeScreen(onContinueWithGoogle: () async {}),
        ),
      );
      await tester.runAsync(() async {
        final context = tester.element(find.byType(Scaffold));
        await precacheImage(
          const AssetImage('assets/images/the-compass.png'),
          context,
        );
      });
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/member_entry_${brightness.name}.png'),
      );
    });

    testWidgets('captures Google member entry in ${brightness.name}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: brightness == Brightness.light
              ? AppTheme.light
              : AppTheme.dark,
          home: MemberSignInScreen(onContinueWithGoogle: () async {}),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/member_sign_in_${brightness.name}.png'),
      );
    });

    testWidgets('captures an onboarding choice in ${brightness.name}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = OnboardingController(
        initialDraft: const OnboardingDraft(
          experience: InvestingExperience.someExperience,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: brightness == Brightness.light
              ? AppTheme.light
              : AppTheme.dark,
          home: OnboardingFlow(
            controller: controller,
            step: OnboardingStep.experience,
            onContinue: (_) {},
            onBack: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/onboarding_choice_${brightness.name}.png'),
      );
    });
  }
}

Future<void> _loadFont(String family, String asset) async {
  final loader = FontLoader(family)..addFont(rootBundle.load(asset));
  await loader.load();
}
