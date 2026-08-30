abstract interface class MemberAuthSignal {
  Stream<void> get logoutEvents;
  void publishLogout();
  void close();
}

class NoopMemberAuthSignal implements MemberAuthSignal {
  const NoopMemberAuthSignal();

  @override
  Stream<void> get logoutEvents => const Stream<void>.empty();
  @override
  void publishLogout() {}
  @override
  void close() {}
}
