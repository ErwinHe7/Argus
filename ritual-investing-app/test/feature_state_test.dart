import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/api/state_status.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/discover/application/controller.dart';
import 'package:ritual_investing_app/features/discover/data/repository.dart';
import 'package:ritual_investing_app/features/discover/domain/model.dart';
import 'package:ritual_investing_app/features/discover/presentation/discover_screen.dart';
import 'package:ritual_investing_app/features/profile/application/controller.dart';
import 'package:ritual_investing_app/features/profile/data/repository.dart';
import 'package:ritual_investing_app/features/profile/domain/model.dart';
import 'package:ritual_investing_app/features/profile/presentation/profile_screen.dart';
import 'package:ritual_investing_app/features/portfolio/application/controller.dart';
import 'package:ritual_investing_app/features/portfolio/data/repository.dart';
import 'package:ritual_investing_app/features/portfolio/domain/model.dart';
import 'package:ritual_investing_app/features/ritual/application/daily_ritual_controller.dart';
import 'package:ritual_investing_app/features/ritual/data/daily_ritual_repository.dart';
import 'package:ritual_investing_app/features/ritual/domain/daily_ritual.dart';
import 'package:ritual_investing_app/features/ritual/presentation/daily_ritual_screen.dart';

void main() {
  for (final phase in [
    LoadPhase.loading,
    LoadPhase.stale,
    LoadPhase.empty,
    LoadPhase.forbidden,
    LoadPhase.throttled,
    LoadPhase.conflict,
    LoadPhase.retryableFailure,
  ]) {
    testWidgets('renders ${phase.name} state with accessible semantics', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StateStatus(phase: phase, onRetry: () {}),
          ),
        ),
      );
      expect(find.byKey(Key('state-${phase.name}')), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(Key('state-${phase.name}'))).label,
        isNotEmpty,
      );
    });
  }

  testWidgets(
    'Discover does not substitute fixture data for a forbidden server response',
    (tester) async {
      final controller = DiscoverController(repository: _FailureRepository());
      await controller.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: DiscoverScreen(controller: controller)),
        ),
      );
      expect(find.byKey(const Key('state-forbidden')), findsOneWidget);
      expect(find.text('Quiet Power'), findsNothing);
    },
  );

  testWidgets('screens do not render literal data without server authority', (
    tester,
  ) async {
    final ritual = DailyRitualController(
      repository: DailyRitualRepository(
        service: _ForbiddenRitualService(),
        cache: MemoryReadCache(),
      ),
    );
    await ritual.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: DailyRitualScreen(
            controller: ritual,
            onOpenCoven: () {},
            onToggleTheme: () {},
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('state-forbidden')), findsOneWidget);
    expect(find.text('YOUR DAILY SIGNAL'), findsNothing);
    expect(find.text('VIG'), findsNothing);

    final profile = ProfileController(repository: _FailureProfileRepository());
    final portfolio = PortfolioController(
      repository: _FailurePortfolioRepository(),
    );
    await profile.load();
    await portfolio.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ProfileScreen(
            controller: profile,
            portfolioController: portfolio,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('state-forbidden')), findsNWidgets(2));
    expect(find.text('SIMULATED BALANCE'), findsNothing);
    expect(find.text('Build a six-month calm fund'), findsNothing);
  });
}

class _FailureRepository implements DiscoverRepository {
  @override
  Future<RepositoryRead<DiscoverModel>> load() =>
      Future.error(const LoadFailure(LoadPhase.forbidden));
}

class _ForbiddenRitualService implements DailyRitualService {
  @override
  Future<DailyRitual> fetchDaily() =>
      Future.error(const LoadFailure(LoadPhase.forbidden));
}

class _FailureProfileRepository implements ProfileRepository {
  @override
  Future<RepositoryRead<ProfileModel>> load() =>
      Future.error(const LoadFailure(LoadPhase.forbidden));

  @override
  Future<RepositoryRead<ProfileModel>> updatePreferences(
    ProfilePreferencesUpdate update,
  ) => Future.error(const LoadFailure(LoadPhase.forbidden));

  @override
  Future<RepositoryRead<ProfileModel>> updateInvestor(
    ProfileInvestorUpdate update,
  ) => Future.error(const LoadFailure(LoadPhase.forbidden));

  @override
  Future<RepositoryRead<ProfileModel>> updateAstrology(
    ProfileAstrologyUpdate update,
  ) => Future.error(const LoadFailure(LoadPhase.forbidden));

  @override
  Future<RepositoryRead<ProfileModel>> deleteAstrology({
    required int expectedVersion,
  }) => Future.error(const LoadFailure(LoadPhase.forbidden));
}

class _FailurePortfolioRepository implements PortfolioRepository {
  @override
  Future<RepositoryRead<PortfolioCollection>> load() =>
      Future.error(const LoadFailure(LoadPhase.forbidden));

  @override
  Future<ContributionReceipt> contribute({
    required String portfolioId,
    required String sourceId,
    required int minorUnits,
    required String idempotencyKey,
  }) => Future.error(const LoadFailure(LoadPhase.forbidden));
}
