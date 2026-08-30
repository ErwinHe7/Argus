import 'package:flutter/material.dart';

class MemberSignInScreen extends StatefulWidget {
  const MemberSignInScreen({
    super.key,
    this.onSubmit,
    this.title = 'Sign in',
    this.submitLabel = 'Sign in',
    this.submittingLabel = 'Signing in…',
    this.onForgotPassword,
  });

  final Future<void> Function(String email, String password)? onSubmit;
  final String title;
  final String submitLabel;
  final String submittingLabel;
  final VoidCallback? onForgotPassword;

  @override
  State<MemberSignInScreen> createState() => _MemberSignInScreenState();
}

class _MemberSignInScreenState extends State<MemberSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            TextFormField(
              key: const Key('member-sign-in-email'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter your email.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('member-sign-in-password'),
              controller: _passwordController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (value) => value == null || value.isEmpty
                  ? 'Enter your password.'
                  : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('member-sign-in-submit'),
              onPressed: _isSubmitting ? null : _submit,
              child: Text(
                _isSubmitting ? widget.submittingLabel : widget.submitLabel,
              ),
            ),
            if (widget.onForgotPassword != null)
              TextButton(
                key: const Key('member-forgot-password'),
                onPressed: _isSubmitting ? null : widget.onForgotPassword,
                child: const Text('Forgot password?'),
              ),
          ],
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
