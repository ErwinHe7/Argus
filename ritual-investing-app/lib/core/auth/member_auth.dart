// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

enum MemberAuthIntentKind { signIn, signUp, recentAuth }

class MemberAuthCancelled implements Exception {
  const MemberAuthCancelled();
}

@immutable
class MemberAuthIntent {
  const MemberAuthIntent.signIn()
    : kind = MemberAuthIntentKind.signIn,
      maxAge = null;

  const MemberAuthIntent.signUp()
    : kind = MemberAuthIntentKind.signUp,
      maxAge = null;

  const MemberAuthIntent.recentAuth({required Duration maxAge})
    : maxAge = maxAge,
      kind = MemberAuthIntentKind.recentAuth;

  final MemberAuthIntentKind kind;
  final Duration? maxAge;

  @override
  bool operator ==(Object other) =>
      other is MemberAuthIntent && other.kind == kind && other.maxAge == maxAge;

  @override
  int get hashCode => Object.hash(kind, maxAge);
}

@immutable
class MemberClientExpectation {
  const MemberClientExpectation({required this.authorizedParty})
    : assert(authorizedParty != '');

  final String authorizedParty;
}

@immutable
class AuthSession {
  const AuthSession({required this.accessToken});

  final String accessToken;
}

abstract interface class SessionRepository {
  MemberClientExpectation get memberClientExpectation;
  Stream<AuthSession> get recoveredSessions;
  Future<AuthSession> authenticate(MemberAuthIntent intent);
  Future<AuthSession?> recover();
  Future<void> logout();
}
