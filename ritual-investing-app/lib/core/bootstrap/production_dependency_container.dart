import 'dart:convert';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:ritual_investing_api_client/generated/api.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/onboarding/data/onboarding_draft_store.dart';
import '../../features/onboarding/data/onboarding_repository.dart';
import '../../features/privacy/data/private_export_files.dart';
import '../../features/privacy/data/repository.dart';
import '../api/flutter_protected_storage.dart';
import '../api/pending_command_store.dart';
import '../api/ritual_api.dart';
import '../auth/auth_controller.dart';
import '../auth/supabase_session_repository.dart';
import '../auth/member_step_up.dart';
import '../cache/read_cache.dart';
import '../config/runtime_config.dart';
import 'dependency_container.dart';
import 'entry_coordinator.dart';
import 'production_member_feature_scope_factory.dart';

DependencyContainer createProductionDependencyContainer(RuntimeConfig config) {
  final cache = MemoryReadCache();
  final protectedStorage = FlutterProtectedStorage();
  final pendingCommandStore = PendingCommandStore(storage: protectedStorage);
  late final RitualInvestingApiClient client;
  final auth = AuthController(
    repository: SupabaseSessionRepository.production(
      client: Supabase.instance.client,
      provider: config.memberAuthProviders.primary,
      nativeLinks: config.nativeLinks,
      supabaseUrl: config.supabaseUrl,
    ),
    stepUpReceipts: ApiStepUpReceiptRepository.fromClientProvider(() => client),
  );
  client = RitualInvestingApiClient(
    basePathOverride: config.apiBaseUrl,
    interceptors: [RitualAuthInterceptor(tokenProvider: auth)],
  );
  final onboardingDraftStore = OnboardingDraftStore(
    storage: protectedStorage,
    installation: AppContainerInstallationBinding(
      cacheDirectoryProvider: getTemporaryDirectory,
    ),
    now: DateTime.now,
  );
  final privacyExportRequestStore = PrivacyExportRequestStore(
    storage: protectedStorage,
  );
  final privateExportFiles = FlutterPrivateExportFiles();
  final entryCoordinator = EntryCoordinator(
    authController: auth,
    bootstrapService: GeneratedSessionBootstrapService(client),
    draftStore: onboardingDraftStore,
    onboardingRepository: GeneratedOnboardingRepository(client),
  );
  return DependencyContainer(
    authController: auth,
    sessionBootstrapService: GeneratedSessionBootstrapService(client),
    cacheStorage: cache,
    pendingCommandStore: pendingCommandStore,
    entryCoordinator: entryCoordinator,
    featureScopeFactory: ProductionMemberFeatureScopeFactory(
      client: client,
      pendingCommandStore: pendingCommandStore,
      authController: auth,
      privacyExportRequestStore: privacyExportRequestStore,
      privateExportFiles: privateExportFiles,
      createCommandKey: _newCommandKey,
      now: DateTime.now,
    ).call,
  );
}

String _newCommandKey() {
  final random = Random.secure();
  return base64UrlEncode(List<int>.generate(24, (_) => random.nextInt(256)))
      .replaceAll('=', '');
}
