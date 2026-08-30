import 'package:app_links/app_links.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/brokerage_connection/data/repository.dart';
import '../../features/onboarding/data/onboarding_draft_store.dart';
import '../../features/onboarding/data/onboarding_installation_binding_io.dart';
import '../../features/privacy/data/private_export_files_io.dart';
import '../../features/privacy/data/repository.dart';
import '../api/pending_command_store.dart';
import '../auth/member_auth.dart';
import 'entry_coordinator.dart';

OnboardingDraftStore createProductionOnboardingDraftStore({
  required ProtectedStorage nativeStorage,
  required DateTime Function() now,
}) => OnboardingDraftStore(
  storage: nativeStorage,
  installation: AppContainerInstallationBinding(
    cacheDirectoryProvider: getTemporaryDirectory,
  ),
  now: now,
);

PrivateExportFiles createProductionPrivateExportFiles() =>
    FlutterPrivateExportFiles();

void bindProductionBrokerageNativeLinks({
  required EntryCoordinator coordinator,
  required MemberNativeLinkPolicy policy,
  required BrokerageConnectionRepository Function() brokerageConnections,
}) {
  final appLinks = AppLinks();
  final repository = brokerageConnections();
  coordinator.bindBrokerageNativeLinks(
    policy: policy,
    initialLink: appLinks.getInitialLink,
    links: appLinks.uriLinkStream,
    redeemCompletion: repository.redeemCompletion,
  );
}
