import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/cache/cached_read.dart';
import 'package:ritual_investing_app/features/onboarding/domain/onboarding_draft.dart';
import 'package:ritual_investing_app/features/profile/application/controller.dart';
import 'package:ritual_investing_app/features/profile/data/repository.dart';
import 'package:ritual_investing_app/features/profile/domain/model.dart';
import 'package:ritual_investing_app/features/profile/presentation/profile_screen.dart';

void main() {
  testWidgets('You is a summary menu with focused member settings', (
    tester,
  ) async {
    final profile = _controller();
    await profile.load();
    var opened = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileScreen(
            controller: profile,
            onOpenInvesting: () => opened = 'investing',
            onOpenRitualPreferences: () => opened = 'ritual',
            onOpenAstrology: () => opened = 'astrology',
            onOpenPolicies: () => opened = 'policies',
            onOpenPlansAndPayment: () => opened = 'plans-and-payment',
            onOpenAccount: () => opened = 'account',
            onOpenPortfolio: (_) => opened = 'portfolio',
          ),
        ),
      ),
    );

    expect(find.text('You'), findsOneWidget);
    expect(find.byKey(const Key('you-investing')), findsOneWidget);
    expect(find.byKey(const Key('you-ritual-preferences')), findsOneWidget);
    expect(find.byKey(const Key('you-astrology')), findsOneWidget);
    expect(find.byKey(const Key('you-policies')), findsOneWidget);
    expect(find.byKey(const Key('you-plans-and-payment')), findsOneWidget);
    expect(find.byKey(const Key('you-account')), findsOneWidget);
    expect(find.byKey(const Key('you-portfolio')), findsNothing);
    await tester.tap(find.byKey(const Key('you-investing')));
    expect(opened, 'investing');
    await tester.tap(find.byKey(const Key('you-plans-and-payment')));
    expect(opened, 'plans-and-payment');
  });

  testWidgets('investing screen explains active simulation personalization', (
    tester,
  ) async {
    final controller = _controller();
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        home: InvestingProfileScreen(
          controller: controller,
          onSave: controller.updateInvestor,
        ),
      ),
    );

    expect(find.text('Investing profile'), findsOneWidget);
    expect(find.text('Simulation profile'), findsOneWidget);
    expect(find.text('Foundational explanations'), findsOneWidget);
    expect(
      find.text('Long-term growth, Long horizon, Moderate risk framing'),
      findsOneWidget,
    );
    expect(find.text('Monthly'), findsOneWidget);
  });

  testWidgets('investor edit saves through the authoritative callback', (
    tester,
  ) async {
    final controller = _controller();
    await controller.load();
    ProfileInvestorUpdate? written;
    final riskField = find.byWidgetPredicate(
      (widget) => widget is DropdownButtonFormField<RiskComfort>,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: InvestingProfileScreen(
          controller: controller,
          onSave: (update) async {
            written = update;
            return true;
          },
        ),
      ),
    );
    await tester.scrollUntilVisible(
      riskField,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -120));
    await tester.pump();
    await tester.tap(riskField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Higher').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('investing-save')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('investing-save')));
    await tester.pump();

    expect(written?.risk, RiskComfort.high);
    expect(written?.experience, InvestingExperience.newToInvesting);
    expect(written?.horizon, InvestmentHorizon.long);
    expect(written?.expectedVersion, 5);
  });

  testWidgets('theme selection saves through authoritative callback', (
    tester,
  ) async {
    final controller = _controller();
    await controller.load();
    ProfilePreferencesUpdate? written;

    await tester.pumpWidget(
      MaterialApp(
        home: RitualPreferencesScreen(
          controller: controller,
          onSave: (update) async {
            written = update;
            return true;
          },
        ),
      ),
    );
    expect(find.text('Practical, plain-language guidance'), findsOneWidget);
    expect(
      find.text('New to Gospel guidance pacing · Practical research'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('theme-dark')));
    await tester.scrollUntilVisible(
      find.byKey(const Key('preferences-save')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('preferences-save')));
    await tester.pump();

    expect(written?.expectedVersion, 3);
    expect(written?.theme, ProfileTheme.dark);
  });

  testWidgets('astrology birth-data deletion requires confirmation', (
    tester,
  ) async {
    final repository = _ReadyProfileRepository(_profile(withAstrology: true));
    final controller = ProfileController(repository: repository);
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(home: AstrologySettingsScreen(controller: controller)),
    );
    expect(find.text('Server-derived profile'), findsOneWidget);
    expect(find.text('1994-05-14'), findsOneWidget);
    await tester.tap(find.byKey(const Key('astrology-delete')));
    await tester.pumpAndSettle();

    expect(find.text('Delete birth data?'), findsOneWidget);
    expect(repository.deleteCalls, 0);
    await tester.tap(find.byKey(const Key('confirm-astrology-delete')));
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, 1);
  });

  testWidgets('policy screen is honest about available consent authority', (
    tester,
  ) async {
    final controller = _controller();
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: PolicyStatusScreen(
          controller: controller,
          onboardingComplete: true,
        ),
      ),
    );

    expect(find.text('Onboarding complete'), findsOneWidget);
    expect(find.textContaining('Accepted during onboarding'), findsNothing);
    expect(find.textContaining('v2026-08'), findsNothing);
    expect(
      find.textContaining('required for current member v2 onboarding'),
      findsNWidgets(3),
    );
    expect(
      find.textContaining('current and detailed consent receipts'),
      findsOneWidget,
    );
  });

  testWidgets('You menu remains scrollable with large text', (tester) async {
    final profile = _controller();
    await profile.load();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
        child: MaterialApp(
          home: Scaffold(body: ProfileScreen(controller: profile)),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

ProfileController _controller() =>
    ProfileController(repository: _ReadyProfileRepository(_profile()));

ProfileModel _profile({bool withAstrology = false}) => ProfileModel(
  displayName: 'Ritual Member',
  profileVersion: 2,
  preferences: const SavedRitualPreferences(
    locale: 'en-US',
    timezone: 'America/New_York',
    ritualFamiliarity: RitualFamiliarity.newToRitual,
    ritualLanguage: RitualLanguage.practical,
    ritualInterests: {RitualInterest.practicalResearch},
    ritualMode: ProfileRitualMode.tarot,
    theme: ProfileTheme.system,
    version: 3,
  ),
  investor: const SavedInvestorProfile(
    experience: InvestingExperience.newToInvesting,
    goal: InvestmentGoal.longTermGrowth,
    horizon: InvestmentHorizon.long,
    risk: RiskComfort.moderate,
    contributionRhythm: ContributionRhythm.monthly,
    isDemo: true,
    version: 5,
  ),
  astrology: withAstrology
      ? SavedAstrologyProfile(
          birthDate: ProfileDate(1994, 5, 14),
          serverDerivedProfile: 'solar_builder',
          algorithmVersion: 'v1',
          version: 4,
        )
      : null,
  astrologyDecision: withAstrology
      ? ProfileConsentDecision.accepted
      : ProfileConsentDecision.unknown,
);

class _ReadyProfileRepository implements ProfileRepository {
  _ReadyProfileRepository(this.value);
  ProfileModel value;
  int deleteCalls = 0;

  RepositoryRead<ProfileModel> get read => RepositoryRead(
    value: value,
    isStale: false,
    committedAt: DateTime.utc(2026, 8, 25),
  );

  @override
  Future<RepositoryRead<ProfileModel>> load() async => read;
  @override
  Future<RepositoryRead<ProfileModel>> updatePreferences(
    ProfilePreferencesUpdate update,
  ) async => read;
  @override
  Future<RepositoryRead<ProfileModel>> updateInvestor(
    ProfileInvestorUpdate update,
  ) async => read;
  @override
  Future<RepositoryRead<ProfileModel>> updateAstrology(
    ProfileAstrologyUpdate update,
  ) async => read;
  @override
  Future<RepositoryRead<ProfileModel>> deleteAstrology({
    required int expectedVersion,
  }) async {
    deleteCalls += 1;
    value = value.copyWith(
      clearAstrology: true,
      astrologyDecision: ProfileConsentDecision.withdrawn,
    );
    return read;
  }
}
