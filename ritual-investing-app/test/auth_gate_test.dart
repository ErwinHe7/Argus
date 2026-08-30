import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/ritual_investing_app.dart';
import 'package:ritual_investing_app/core/api/ritual_api.dart';
import 'package:ritual_investing_app/core/auth/member_auth.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';

import 'support/fixture_services.dart';

void main() {
  testWidgets('auth gate renders loading then signed-out state', (
    tester,
  ) async {
    final repository = _GateSessionRepository.pending();
    final container = fixtureContainer(sessionRepository: repository);
    await tester.pumpWidget(RitualInvestingApp(container: container));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Restoring your session'), findsOneWidget);

    repository.completeRestore(null);
    await tester.pumpAndSettle();
    expect(
      find.text('Sign in to continue your private ritual.'),
      findsOneWidget,
    );
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('auth gate offers retry after a restore failure', (tester) async {
    await tester.pumpWidget(
      RitualInvestingApp(
        container: fixtureContainer(
          sessionRepository: _GateSessionRepository.failure(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign-in is temporarily unavailable.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('bootstrap failure offers logout and returns to sign in', (
    tester,
  ) async {
    final repository = _GateSessionRepository.signedIn();
    await tester.pumpWidget(
      RitualInvestingApp(
        container: fixtureContainer(
          sessionRepository: repository,
          sessionBootstrapService: _FailingSessionBootstrapService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Your account could not be prepared. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(repository.logoutCalls, 1);
    expect(
      find.text('Sign in to continue your private ritual.'),
      findsOneWidget,
    );
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('sign-in transitions from the gate to the authenticated shell', (
    tester,
  ) async {
    final container = fixtureContainer(
      sessionRepository: _GateSessionRepository.signedOut(),
    );
    await tester.pumpWidget(RitualInvestingApp(container: container));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('member-sign-in-email')),
      'member@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('member-sign-in-password')),
      'local-test-password',
    );
    await tester.tap(find.byKey(const Key('member-sign-in-submit')));
    await tester.pumpAndSettle();
    expect(container.memberBootstrap, isNotNull);
    expect(find.byKey(const Key('app-shell-scaffold')), findsOneWidget);
  });
}

class _GateSessionRepository
    implements SessionRepository, PasswordSessionRepository {
  _GateSessionRepository._({required this.restore, this.failRestore = false});

  factory _GateSessionRepository.pending() =>
      _GateSessionRepository._(restore: Completer<AuthSession?>());

  factory _GateSessionRepository.failure() => _GateSessionRepository._(
    restore: Completer<AuthSession?>()..complete(null),
    failRestore: true,
  );

  factory _GateSessionRepository.signedOut() => _GateSessionRepository._(
    restore: Completer<AuthSession?>()..complete(null),
  );

  factory _GateSessionRepository.signedIn() => _GateSessionRepository._(
    restore: Completer<AuthSession?>()
      ..complete(const AuthSession(accessToken: 'access-token')),
  );

  final Completer<AuthSession?> restore;
  final bool failRestore;
  int logoutCalls = 0;

  @override
  MemberClientExpectation get memberClientExpectation =>
      const MemberClientExpectation(issuer: 'https://member-auth.test/auth/v1');

  @override
  Stream<AuthSession> get recoveredSessions => const Stream.empty();

  void completeRestore(AuthSession? session) => restore.complete(session);

  @override
  Future<AuthSession?> recover() async {
    if (failRestore) throw StateError('Auth unavailable');
    return restore.future;
  }

  @override
  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  }) async => const AuthSession(accessToken: 'access-token');

  @override
  Future<AuthSession> signUpWithPassword({
    required String email,
    required String password,
  }) async => const AuthSession(accessToken: 'access-token');

  @override
  Future<void> logout() async {
    logoutCalls++;
  }
}

class _FailingSessionBootstrapService implements SessionBootstrapService {
  @override
  Future<MemberBootstrap> bootstrap() =>
      Future.error(StateError('bootstrap failed'));
}
