import 'package:integration_test/integration_test.dart';

import 'member_entry_test.dart' as entry;
import 'member_onboarding_test.dart' as onboarding;
import 'privacy_reset_test.dart' as privacy;
import 'starpath_member_flow_test.dart' as starpath;
import 'u4_member_flow_test.dart' as ritual_research;
import 'u5_member_flow_test.dart' as community;
import 'u9_briefings_notifications_test.dart' as engagement;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  entry.main();
  onboarding.main();
  ritual_research.main();
  community.main();
  engagement.main();
  starpath.main();
  privacy.main();
}
