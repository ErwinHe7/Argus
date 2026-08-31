import 'package:flutter/material.dart';

class MemberSignInScreen extends StatefulWidget {
  const MemberSignInScreen({
    super.key,
    this.onSubmit,
    this.title = 'Sign in',
    this.submitLabel = 'Sign in',
    this.submittingLabel = 'Signing in…',
    this.onForgotPassword,
    this.confirmPassword = false,
    this.minimumPasswordLength = 1,
    this.message,
    this.secondaryLabel,
    this.onSecondaryAction,
  });

  final Future<void> Function(String email, String password)? onSubmit;
  final String title;
  final String submitLabel;
  final String submittingLabel;
  final VoidCallback? onForgotPassword;
  final bool confirmPassword;
  final int minimumPasswordLength;
  final String? message;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryAction;

  @override
  State<MemberSignInScreen> createState() => _MemberSignInScreenState();
}

class _MemberSignInScreenState extends State<MemberSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirmation = true;

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit?.call(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ritual')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.confirmPassword
                        ? 'Create a private account for your ritual, preferences, and saved research.'
                        : 'Return to your ritual, saved research, and preferences.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (widget.message != null) ...[
                    const SizedBox(height: 20),
                    _AuthMessage(message: widget.message!),
                  ],
                  const SizedBox(height: 28),
                  TextFormField(
                    key: const Key('member-sign-in-email'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.none,
                    autocorrect: false,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'you@example.com',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter your email.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('member-sign-in-password'),
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: widget.confirmPassword
                        ? TextInputAction.next
                        : TextInputAction.done,
                    autofillHints: [
                      widget.confirmPassword
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        key: const Key('member-password-visibility'),
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter your password.';
                      }
                      if (value.length < widget.minimumPasswordLength) {
                        return 'Use at least ${widget.minimumPasswordLength} characters.';
                      }
                      return null;
                    },
                    onFieldSubmitted: widget.confirmPassword
                        ? null
                        : (_) => _submit(),
                  ),
                  if (widget.confirmPassword) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('member-sign-in-password-confirmation'),
                      controller: _passwordConfirmationController,
                      obscureText: _obscurePasswordConfirmation,
                      enableSuggestions: false,
                      autocorrect: false,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'Confirm password',
                        suffixIcon: IconButton(
                          key: const Key(
                            'member-password-confirmation-visibility',
                          ),
                          tooltip: _obscurePasswordConfirmation
                              ? 'Show confirmed password'
                              : 'Hide confirmed password',
                          onPressed: () => setState(
                            () => _obscurePasswordConfirmation =
                                !_obscurePasswordConfirmation,
                          ),
                          icon: Icon(
                            _obscurePasswordConfirmation
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value != _passwordController.text
                          ? 'Passwords do not match.'
                          : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('member-sign-in-submit'),
                      onPressed: _isSubmitting ? null : _submit,
                      child: Text(
                        _isSubmitting
                            ? widget.submittingLabel
                            : widget.submitLabel,
                      ),
                    ),
                  ),
                  if (widget.onForgotPassword != null) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      key: const Key('member-forgot-password'),
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
                      onPressed: _isSubmitting ? null : widget.onForgotPassword,
                      child: const Text('Forgot password?'),
                    ),
                  ],
                  if (widget.secondaryLabel != null &&
                      widget.onSecondaryAction != null) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      key: const Key('member-auth-secondary-action'),
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
                      onPressed: _isSubmitting
                          ? null
                          : widget.onSecondaryAction,
                      child: Text(widget.secondaryLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class MemberPasswordScreen extends StatefulWidget {
  const MemberPasswordScreen.forgot({super.key, required this.onSubmit})
    : isReset = false;

  const MemberPasswordScreen.reset({super.key, required this.onSubmit})
    : isReset = true;

  final bool isReset;
  final Future<void> Function(String value) onSubmit;

  @override
  State<MemberPasswordScreen> createState() => _MemberPasswordScreenState();
}

class _MemberPasswordScreenState extends State<MemberPasswordScreen> {
  final _controller = TextEditingController();
  bool _submitted = false;
  bool _busy = false;

  Future<void> _submit() async {
    if (_busy || _controller.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.onSubmit(_controller.text.trim());
      if (mounted) setState(() => _submitted = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.isReset ? 'Set new password' : 'Reset password'),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_submitted && !widget.isReset)
            const Text(
              'If this email is eligible, password recovery instructions are on the way.',
              key: Key('password-recovery-sent'),
            )
          else ...[
            TextField(
              key: Key(
                widget.isReset
                    ? 'member-new-password'
                    : 'member-recovery-email',
              ),
              controller: _controller,
              obscureText: widget.isReset,
              keyboardType: widget.isReset
                  ? TextInputType.visiblePassword
                  : TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: widget.isReset ? 'New password' : 'Email',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('member-password-submit'),
              onPressed: _busy ? null : _submit,
              child: Text(widget.isReset ? 'Set password' : 'Send reset link'),
            ),
          ],
        ],
      ),
    ),
  );
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
