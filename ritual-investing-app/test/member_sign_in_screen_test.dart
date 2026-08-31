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

  testWidgets('password visibility uses an explicit accessible control', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MemberSignInScreen()));

    final editable = find.descendant(
      of: find.byKey(const Key('member-sign-in-password')),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(editable).obscureText, isTrue);

    await tester.tap(find.byKey(const Key('member-password-visibility')));
    await tester.pump();

    expect(tester.widget<EditableText>(editable).obscureText, isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('account creation confirms the password before submitting', (
    tester,
  ) async {
    var submissions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MemberSignInScreen(
          title: 'Create account',
          submitLabel: 'Create account',
          confirmPassword: true,
          minimumPasswordLength: 10,
          onSubmit: (_, _) async => submissions++,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('member-sign-in-email')),
      'new-member@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('member-sign-in-password')),
      'short',
    );
    await tester.enterText(
      find.byKey(const Key('member-sign-in-password-confirmation')),
      'different',
    );
    await tester.tap(find.byKey(const Key('member-sign-in-submit')));
    await tester.pump();

    expect(find.text('Use at least 10 characters.'), findsOneWidget);
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(submissions, 0);

    await tester.enterText(
      find.byKey(const Key('member-sign-in-password')),
      'correct horse battery staple',
    );
    await tester.enterText(
      find.byKey(const Key('member-sign-in-password-confirmation')),
      'correct horse battery staple',
    );
    await tester.tap(find.byKey(const Key('member-sign-in-submit')));
    await tester.pumpAndSettle();

    expect(submissions, 1);
  });
}
