import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/core/cache/cached_read.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/onboarding/domain/onboarding_draft.dart';
import 'package:ritual_investing_app/features/profile/application/controller.dart';
import 'package:ritual_investing_app/features/profile/data/repository.dart';
import 'package:ritual_investing_app/features/profile/domain/model.dart';

void main() {
  test('conflict refetches authority and reports changed elsewhere', () async {
    final repository = _ProfileRepository(_profile());
    final controller = ProfileController(repository: repository);
    await controller.load();
    repository.failure = const LoadFailure(LoadPhase.conflict);
    repository.authoritative = _profile(theme: ProfileTheme.dark);
    const edit = ProfilePreferencesUpdate(
      expectedVersion: 3,
      theme: ProfileTheme.light,
    );

    final saved = await controller.updatePreferences(edit);

    expect(saved, isFalse);
    expect(controller.state.phase, LoadPhase.conflict);
    expect(controller.state.value?.preferences.theme, ProfileTheme.dark);
    expect(controller.message, contains('changed elsewhere'));
    expect(
      edit.theme,
      ProfileTheme.light,
      reason: 'editable choice is retained',
    );
  });

  test(
    'network failure is retryable and retains server-backed value',
    () async {
      final repository = _ProfileRepository(_profile());
      final controller = ProfileController(repository: repository);
      await controller.load();
      repository.failure = const OfflineException();

      final saved = await controller.updateInvestor(
        const ProfileInvestorUpdate(
          expectedVersion: 5,
          goal: InvestmentGoal.income,
          horizon: InvestmentHorizon.medium,
          risk: RiskComfort.low,
        ),
      );

      expect(saved, isFalse);
      expect(controller.state.phase, LoadPhase.retryableFailure);
      expect(controller.state.value, isNotNull);
      expect(controller.message, contains('Try again'));
    },
  );

  test(
    'astrology delete failure still refetches and drops absent birth data',
    () async {
      final repository = _ProfileRepository(_profile(withAstrology: true));
      final controller = ProfileController(repository: repository);
      await controller.load();
      repository.failure = const OfflineException();
      repository.authoritative = _profile();

      final saved = await controller.deleteAstrology(expectedVersion: 4);

      expect(saved, isFalse);
      expect(controller.state.value?.astrology, isNull);
      expect(controller.state.phase, LoadPhase.retryableFailure);
    },
  );

  test(
    'completed server deletion clears cached birth data if consent write fails',
    () async {
      final service = _PartialDeleteService(_profile(withAstrology: true));
      final controller = ProfileController(
        repository: CachedProfileRepository(
          service: service,
          cache: MemoryReadCache(),
          now: () => DateTime.utc(2026, 8, 25),
        ),
      );
      await controller.load();
      service.afterDeletion = true;

      final saved = await controller.deleteAstrology(expectedVersion: 4);

      expect(saved, isFalse);
      expect(controller.state.phase, LoadPhase.retryableFailure);
      expect(controller.state.value?.astrology, isNull);
      expect(
        controller.state.value?.astrologyDecision,
        ProfileConsentDecision.unknown,
      );
    },
  );
}

ProfileModel _profile({
  ProfileTheme theme = ProfileTheme.system,
  bool withAstrology = false,
}) => ProfileModel(
  displayName: 'Ritual Member',
  profileVersion: 2,
  preferences: SavedRitualPreferences(
    locale: 'en-US',
    timezone: 'America/New_York',
    ritualMode: ProfileRitualMode.tarot,
    theme: theme,
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
);

class _ProfileRepository implements ProfileRepository {
  _ProfileRepository(this.authoritative);

  ProfileModel authoritative;
  Object? failure;

  RepositoryRead<ProfileModel> get _read => RepositoryRead(
    value: authoritative,
    isStale: false,
    committedAt: DateTime.utc(2026, 8, 25),
  );

  @override
  Future<RepositoryRead<ProfileModel>> load() async => _read;

  @override
  Future<RepositoryRead<ProfileModel>> updatePreferences(
    ProfilePreferencesUpdate update,
  ) async {
    if (failure case final Object value) throw value;
    return _read;
  }

  @override
  Future<RepositoryRead<ProfileModel>> updateInvestor(
    ProfileInvestorUpdate update,
  ) async {
    if (failure case final Object value) throw value;
    return _read;
  }

  @override
  Future<RepositoryRead<ProfileModel>> updateAstrology(
    ProfileAstrologyUpdate update,
  ) async {
    if (failure case final Object value) throw value;
    return _read;
  }

  @override
  Future<RepositoryRead<ProfileModel>> deleteAstrology({
    required int expectedVersion,
  }) async {
    if (failure case final Object value) throw value;
    return _read;
  }
}

class _PartialDeleteService implements ProfileService {
  _PartialDeleteService(this.value);
  ProfileModel value;
  bool afterDeletion = false;

  @override
  Future<ProfileModel> fetch() async {
    if (afterDeletion) throw const OfflineException();
    return value;
  }

  @override
  Future<void> patchPreferences(ProfilePreferencesUpdate update) async {}
  @override
  Future<void> putInvestor(ProfileInvestorUpdate update) async {}
  @override
  Future<ProfileConsentReceipt> putAstrology(ProfileAstrologyUpdate update) =>
      throw UnimplementedError();
  @override
  Future<ProfileConsentReceipt> deleteAstrology({
    required int expectedVersion,
  }) {
    value = value.copyWith(clearAstrology: true);
    throw const AstrologyDeletionPartialFailure(LoadPhase.retryableFailure);
  }
}
