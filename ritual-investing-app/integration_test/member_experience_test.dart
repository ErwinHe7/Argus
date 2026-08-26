import 'package:integration_test/integration_test.dart';

import 'demo_membership_test.dart' as membership;
import 'member_entry_test.dart' as entry;
import 'member_onboarding_test.dart' as onboarding;
import 'privacy_reset_test.dart' as privacy;
import 'u4_member_flow_test.dart' as ritual_research;
import 'u5_member_flow_test.dart' as community;
import 'u6_member_flow_test.dart' as portfolio;
import 'u7_simulated_investing_test.dart' as investing;
import 'u8_intentions_future_mirror_test.dart' as intentions;
import 'u9_briefings_notifications_test.dart' as engagement;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  entry.main();
  onboarding.main();
  ritual_research.main();
  community.main();
  portfolio.main();
  investing.main();
  intentions.main();
  engagement.main();
  membership.main();
  privacy.main();
}
