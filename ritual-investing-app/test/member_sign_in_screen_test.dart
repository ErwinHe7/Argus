import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/features/auth/presentation/member_sign_in_screen.dart';

void main() {
  testWidgets('credential sign in requires both email and password', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MemberSignInScreen()));

    await tester.tap(find.byKey(const Key('member-sign-in-submit')));
    await tester.pump();

    expect(find.text('Enter your email.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('credential sign in submits normalized email and password', (
    tester,
  ) async {
    String? submittedEmail;
    String? submittedPassword;
    await tester.pumpWidget(
      MaterialApp(
        home: MemberSignInScreen(
          onSubmit: (email, password) async {
            submittedEmail = email;
            submittedPassword = password;
          },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('member-sign-in-email')),
      '  beta@example.com ',
    );
    await tester.enterText(
      find.byKey(const Key('member-sign-in-password')),
      'correct horse battery staple',
    );
    await tester.tap(find.byKey(const Key('member-sign-in-submit')));
    await tester.pumpAndSettle();

    expect(submittedEmail, 'beta@example.com');
    expect(submittedPassword, 'correct horse battery staple');
  });
}
