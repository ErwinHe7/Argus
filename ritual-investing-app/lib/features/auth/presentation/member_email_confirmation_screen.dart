import 'package:flutter/material.dart';

class MemberEmailConfirmationScreen extends StatelessWidget {
  const MemberEmailConfirmationScreen({
    super.key,
    required this.email,
    required this.onSignIn,
    required this.onUseDifferentEmail,
  });

  final String email;
  final VoidCallback onSignIn;
  final VoidCallback onUseDifferentEmail;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ritual')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            children: [
              Align(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary
                        .withValues(alpha: 0.1),
                  ),
                  child: Icon(
                    Icons.mark_email_unread_outlined,
                    size: 34,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Check your email',
                key: const Key('email-confirmation-title'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'We sent a confirmation link to',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 4),
              SelectableText(
                email,
                key: const Key('email-confirmation-address'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                'Open the link in that email to finish creating your account. Then return here to sign in.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('email-confirmation-sign-in'),
                  onPressed: onSignIn,
                  child: const Text('Go to sign in'),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                key: const Key('email-confirmation-change-email'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: onUseDifferentEmail,
                child: const Text('Use a different email'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
