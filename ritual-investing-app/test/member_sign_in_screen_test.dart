import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/features/auth/presentation/member_sign_in_screen.dart';

void main() {
  testWidgets('Google is the only member authentication action', (
    tester,
  ) async {
    var launches = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MemberSignInScreen(
          onContinueWithGoogle: () async {
            launches += 1;
          },
        ),
      ),
    );

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Continue with Google'), findsOneWidget);

    await tester.tap(find.byKey(const Key('member-google-sign-in')));
    await tester.pumpAndSettle();

    expect(launches, 1);
  });

  testWidgets('Google action disables while the provider opens', (
    tester,
  ) async {
    final barrier = Completer<void>();
    var launches = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MemberSignInScreen(
          onContinueWithGoogle: () {
            launches += 1;
            return barrier.future;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('member-google-sign-in')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('member-google-sign-in')));
    await tester.pump();

    expect(launches, 1);
    expect(find.text('Opening Google…'), findsOneWidget);

    barrier.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('provider failures are announced without credential fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemberSignInScreen(
          onContinueWithGoogle: () async {},
          message: 'Google sign-in is temporarily unavailable.',
        ),
      ),
    );

    expect(find.byKey(const Key('member-auth-message')), findsOneWidget);
    expect(
      find.text('Google sign-in is temporarily unavailable.'),
      findsOneWidget,
    );
    expect(find.byType(EditableText), findsNothing);
  });
}
