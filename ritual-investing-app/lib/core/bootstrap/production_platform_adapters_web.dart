import '../../features/brokerage_connection/data/repository.dart';
import '../../features/onboarding/data/onboarding_draft_store.dart';
import '../../features/onboarding/data/onboarding_installation_binding_web.dart';
import '../../features/privacy/data/private_export_files_web.dart';
import '../../features/privacy/data/repository.dart';
import '../api/pending_command_store.dart';
import '../auth/member_auth.dart';
import 'entry_coordinator.dart';

OnboardingDraftStore createProductionOnboardingDraftStore({
  required ProtectedStorage nativeStorage,
  required DateTime Function() now,
}) => OnboardingDraftStore(
  storage: BrowserSessionOnboardingStorage(),
  installation: BrowserTabInstallationBinding(),
  now: now,
  persistConsentAuthority: false,
);

PrivateExportFiles createProductionPrivateExportFiles() =>
    FlutterPrivateExportFiles();

void bindProductionBrokerageNativeLinks({
  required EntryCoordinator coordinator,
  required MemberNativeLinkPolicy policy,
  required BrokerageConnectionRepository Function() brokerageConnections,
}) {
  // Native-link plugins and provider-completion redemption stay absent on web.
}
