import 'member_auth_signal_base.dart';

MemberAuthSignal createProductionMemberAuthSignal() =>
    const NoopMemberAuthSignal();
