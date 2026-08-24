// ignore_for_file: prefer_initializing_formals

import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:ritual_investing_api_client/generated/api.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';

import '../../features/coven/application/controller.dart';
import '../../features/coven/data/repository.dart';
import '../../features/coven/domain/model.dart';
import '../../features/discover/application/controller.dart';
import '../../features/discover/data/repository.dart';
import '../../features/discover/domain/model.dart';
import '../../features/profile/application/controller.dart';
import '../../features/profile/data/repository.dart';
import '../../features/profile/domain/model.dart';
import '../../features/ritual/application/daily_ritual_controller.dart';
import '../../features/ritual/data/daily_ritual_repository.dart';
import '../../features/ritual/domain/daily_ritual.dart';
import '../api/ritual_api.dart';
import '../auth/auth0_session_repository.dart';
import '../auth/auth_controller.dart';
import '../cache/read_cache.dart';
import '../config/runtime_config.dart';

class DependencyContainer {
  DependencyContainer({
    required this.authController,
    required this.dailyRitualController,
    required this.discoverController,
    required this.covenController,
    required this.profileController,
    required ReadCache cache,
  }) : _cache = cache;

  final AuthController authController;
  final DailyRitualController dailyRitualController;
  final DiscoverController discoverController;
  final CovenController covenController;
  final ProfileController profileController;
  final ReadCache _cache;
  bool _legacyMutationsCleared = false;

  Future<void> bootstrap() async {
    await authController.restore();
    await _loadAuthenticatedState();
  }

  Future<void> login() async {
    await authController.login();
    await _loadAuthenticatedState();
  }

  Future<void> _loadAuthenticatedState() async {
    if (authController.state.phase != AuthPhase.signedIn) return;
    if (!_legacyMutationsCleared) {
      await _cache.clearLegacyMutations();
      _legacyMutationsCleared = true;
    }
    await Future.wait([
      dailyRitualController.load(),
      discoverController.load(),
      covenController.load(),
      profileController.load(),
    ]);
  }

  factory DependencyContainer.production(RuntimeConfig config) {
    final cache = MemoryReadCache();
    final auth = AuthController(
      repository: Auth0SessionRepository(
        auth0: Auth0(config.auth0Domain, config.auth0ClientId),
        audience: config.auth0Audience,
      ),
    );
    final client = RitualInvestingApiClient(
      basePathOverride: config.apiBaseUrl,
      interceptors: [RitualAuthInterceptor(tokenProvider: auth)],
    );
    return DependencyContainer(
      authController: auth,
      dailyRitualController: DailyRitualController(
        repository: DailyRitualRepository(
          service: GeneratedRitualApiService(client),
          cache: cache,
        ),
      ),
      discoverController: DiscoverController(
        repository: CachedDiscoverRepository(
          service: GeneratedDiscoverApiService(client),
          cache: cache,
        ),
      ),
      covenController: CovenController(
        repository: CachedCovenRepository(
          service: GeneratedCovenApiService(client),
          cache: cache,
        ),
      ),
      profileController: ProfileController(
        repository: CachedProfileRepository(
          service: GeneratedProfileApiService(client),
          cache: cache,
        ),
      ),
      cache: cache,
    );
  }

  factory DependencyContainer.fixture({
    ReadCache? cache,
    SessionRepository? sessionRepository,
  }) {
    final fixtureCache = cache ?? MemoryReadCache();
    return DependencyContainer(
      authController: AuthController(
        repository: sessionRepository ?? _FixtureSessionRepository(),
      ),
      dailyRitualController: DailyRitualController(
        repository: DailyRitualRepository(
          service: _FixtureRitualService(),
          cache: fixtureCache,
        ),
      ),
      discoverController: DiscoverController(
        repository: CachedDiscoverRepository(
          service: _FixtureDiscoverService(),
          cache: fixtureCache,
        ),
      ),
      covenController: CovenController(
        repository: CachedCovenRepository(
          service: _FixtureCovenService(),
          cache: fixtureCache,
        ),
      ),
      profileController: ProfileController(
        repository: CachedProfileRepository(
          service: _FixtureProfileService(),
          cache: fixtureCache,
        ),
      ),
      cache: fixtureCache,
    );
  }
}

class _FixtureSessionRepository implements SessionRepository {
  @override
  Future<AuthSession?> credentials() async =>
      const AuthSession(accessToken: 'fixture');
  @override
  Future<AuthSession> login() async =>
      const AuthSession(accessToken: 'fixture');
  @override
  Future<void> logout() async {}
}

class _FixtureRitualService implements DailyRitualService {
  @override
  Future<DailyRitual> fetchDaily() async => const DailyRitual(
    title: 'Direction, not urgency.',
    interpretation: 'The strongest path today rewards patience. Favor durable momentum; let noisy names pass without you.',
  );
}

class _FixtureDiscoverService implements DiscoverService {
  @override
  Future<DiscoverModel> fetch() async => DiscoverModel(
    grimoires: const [
      DiscoverCard(title: 'Quiet Power', subtitle: 'Durability over drama'),
      DiscoverCard(title: 'New Moons', subtitle: 'Early themes to study'),
      DiscoverCard(title: 'Long Horizon', subtitle: 'Patient compounding'),
    ],
    circles: const [
      DiscoverCard(
        title: 'Soft Power Portfolio',
        subtitle: 'A fictional curator’s diversified demo circle',
      ),
      DiscoverCard(
        title: 'Climate Keepers',
        subtitle: 'Themes to compare, edit, and save locally',
      ),
    ],
  );
}

class _FixtureCovenService implements CovenService {
  @override
  Future<CovenModel> fetch() async => CovenModel(
    entries: const [
      CovenEntry(
        name: 'Aurora Healthworks',
        symbol: 'AURA',
        category: 'Woman founder',
        focus: 'Preventive health technology',
      ),
      CovenEntry(
        name: 'Juniper Robotics',
        symbol: 'JNPR',
        category: 'Woman chief executive',
        focus: 'Industrial automation',
      ),
      CovenEntry(
        name: 'Morrow Energy',
        symbol: 'MROW',
        category: 'Women-owned',
        focus: 'Distributed clean energy',
      ),
      CovenEntry(
        name: 'Thistle Foods',
        symbol: 'THST',
        category: 'Woman founder',
        focus: 'Sustainable nutrition',
      ),
    ],
  );
}

class _FixtureProfileService implements ProfileService {
  @override
  Future<ProfileModel> fetch() async =>
      const ProfileModel(displayName: 'Ritual Member');
}
