import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/ritual_investing_app.dart';
import 'package:ritual_investing_app/core/auth/auth0_session_repository.dart';
import 'package:ritual_investing_app/core/bootstrap/dependency_container.dart';

void main() {
  testWidgets('auth gate renders loading then signed-out state', (
    tester,
  ) async {
    final repository = _GateSessionRepository.pending();
    await tester.pumpWidget(
      RitualInvestingApp(
        container: DependencyContainer.fixture(sessionRepository: repository),
      ),
    );
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
        container: DependencyContainer.fixture(
          sessionRepository: _GateSessionRepository.failure(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign-in is temporarily unavailable.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('sign-in transitions from the gate to the authenticated shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      RitualInvestingApp(
        container: DependencyContainer.fixture(
          sessionRepository: _GateSessionRepository.signedOut(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Direction, not urgency.'), findsOneWidget);
  });
}

class _GateSessionRepository implements SessionRepository {
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

  final Completer<AuthSession?> restore;
  final bool failRestore;

  void completeRestore(AuthSession? session) => restore.complete(session);

  @override
  Future<AuthSession?> credentials() async {
    if (failRestore) throw StateError('Auth0 unavailable');
    return restore.future;
  }

  @override
  Future<AuthSession> login() async =>
      const AuthSession(accessToken: 'access-token');

  @override
  Future<void> logout() async {}
}
