import 'package:flutter/material.dart';

class MemberSignInScreen extends StatefulWidget {
  const MemberSignInScreen({
    super.key,
    this.onSubmit,
    this.title = 'Sign in',
    this.submitLabel = 'Sign in',
    this.submittingLabel = 'Signing in…',
  });

  final Future<void> Function(String email, String password)? onSubmit;
  final String title;
  final String submitLabel;
  final String submittingLabel;

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
          ],
        ),
      ),
    ),
  );
}
