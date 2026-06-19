import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/input_field.dart';
import '../widgets/page_header.dart';
import '../widgets/primary_button.dart';
import '../widgets/status_bar.dart';

/// FORGOT PASSWORD — not in the Figma deck; mirrors the LOGIN visual language
/// (pill email field + dark primary CTA) so it slots cleanly into the auth flow.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _sent = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const FakeStatusBar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: PageHeader(title: 'Forgot Password'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      'Reset your password 🔑',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter the email tied to your account. '
                      'We will send a link to reset your password.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textHint,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 32),
                    LabeledField(
                      label: 'Email Address',
                      icon: Icons.email_outlined,
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      hint: 'you@example.com',
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: _busy
                          ? 'Sending…'
                          : (_sent ? 'Link Sent' : 'Send Reset Link'),
                      icon: _sent
                          ? Icons.check_circle_outline_rounded
                          : Icons.arrow_forward_rounded,
                      onPressed: _busy ? null : () => _submit(context),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.maybePop(context),
                        child: const Text(
                          'Back to Sign In',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const NotchArea(),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthService.instance.sendPasswordResetEmail(email);
      if (!context.mounted) return;
      setState(() => _sent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset link sent to $email')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthService.describeError(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
