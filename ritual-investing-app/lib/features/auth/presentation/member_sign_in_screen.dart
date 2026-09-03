import 'package:flutter/material.dart';

class MemberSignInScreen extends StatefulWidget {
  const MemberSignInScreen({
    super.key,
    required this.onContinueWithGoogle,
    this.message,
  });

  final Future<void> Function() onContinueWithGoogle;
  final String? message;

  @override
  State<MemberSignInScreen> createState() => _MemberSignInScreenState();
}

class _MemberSignInScreenState extends State<MemberSignInScreen> {
  bool _isSubmitting = false;

  Future<void> _continueWithGoogle() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.onContinueWithGoogle();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Material(
                  color: scheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: constraints.maxWidth < 420 ? 24 : 40,
                      vertical: constraints.maxHeight < 620 ? 28 : 40,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Image.asset(
                              'assets/images/brand/leo-lion.png',
                              width: 56,
                              height: 56,
                              fit: BoxFit.contain,
                              semanticLabel: 'Leo lion',
                            ),
                            const SizedBox(width: 12),
                            Text('Leo', style: theme.textTheme.headlineMedium),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'PRIVATE MEMBER ACCESS',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Your Gospel, in one place.',
                          key: const Key('member-google-sign-in-title'),
                          style: theme.textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Continue with Google to access your Tarot readings, saved research, and private preferences.',
                          style: theme.textTheme.bodyLarge,
                        ),
                        if (widget.message != null) ...[
                          const SizedBox(height: 24),
                          _AuthMessage(message: widget.message!),
                        ],
                        const SizedBox(height: 32),
                        SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            key: const Key('member-google-sign-in'),
                            onPressed: _isSubmitting
                                ? null
                                : _continueWithGoogle,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: scheme.onSurface,
                              backgroundColor: scheme.surface,
                              side: BorderSide(color: scheme.outline),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isSubmitting)
                                  const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                else
                                  Text(
                                    'G',
                                    semanticsLabel: 'Google',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                const SizedBox(width: 12),
                                Text(
                                  _isSubmitting
                                      ? 'Opening Google…'
                                      : 'Continue with Google',
                                  style: theme.textTheme.labelLarge,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Google verifies your identity. Your Gospel data remains private and is never used to place trades.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthMessage extends StatelessWidget {
  const _AuthMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Material(
        key: const Key('member-auth-message'),
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: scheme.onErrorContainer,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
