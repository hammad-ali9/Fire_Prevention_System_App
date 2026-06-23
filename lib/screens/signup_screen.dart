import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/input_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/status_bar.dart';

/// SIGN UP — not in the Figma deck; mirrors LOGIN visual language. Collects
/// name + email + password + confirm-password and pushes to Home on success.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _agree = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      'Create Account 🚀',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sign up to start monitoring your zones.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textHint,
                      ),
                    ),
                    const SizedBox(height: 32),
                    LabeledField(
                      label: 'Full Name',
                      icon: Icons.person_outline_rounded,
                      controller: _name,
                      hint: 'Raja Saif',
                    ),
                    const SizedBox(height: 14),
                    LabeledField(
                      label: 'Email Address',
                      icon: Icons.email_outlined,
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      hint: 'you@example.com',
                    ),
                    const SizedBox(height: 14),
                    LabeledField(
                      label: 'Password',
                      icon: Icons.lock_outline_rounded,
                      controller: _password,
                      obscureText: _obscure,
                      hint: 'At least 8 characters',
                      suffix: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.textBody,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    const SizedBox(height: 14),
                    LabeledField(
                      label: 'Confirm Password',
                      icon: Icons.lock_outline_rounded,
                      controller: _confirm,
                      obscureText: _obscureConfirm,
                      hint: 'Re-enter password',
                      suffix: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppColors.textBody,
                        ),
                        onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _agree,
                          onChanged: (v) =>
                              setState(() => _agree = v ?? false),
                          activeColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                                children: [
                                  TextSpan(text: 'I agree to the '),
                                  TextSpan(
                                    text: 'Terms',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(text: ' and '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(text: '.'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: _busy ? 'Creating account…' : 'Sign Up',
                      onPressed: _busy ? null : () => _submit(context),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: const [
                        Expanded(
                            child: Divider(
                                color: AppColors.border, height: 1)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: AppColors.textNeutral,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Expanded(
                            child: Divider(
                                color: AppColors.border, height: 1)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SocialButton(
                      label: 'Continue with Google',
                      iconAsset: const Icon(Icons.g_mobiledata_rounded,
                          color: Color(0xFFEA4335), size: 28),
                      onPressed: _busy ? null : _signInWithGoogle,
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.maybePop(context),
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(text: 'Already have an account? '),
                              TextSpan(
                                text: 'Sign In.',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
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
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    final confirm = _confirm.text;

    String? error;
    if (name.isEmpty) {
      error = 'Enter your full name';
    } else if (email.isEmpty || !email.contains('@')) {
      error = 'Enter a valid email address';
    } else if (password.length < 8) {
      error = 'Password must be at least 8 characters';
    } else if (password != confirm) {
      error = 'Passwords do not match';
    } else if (!_agree) {
      error = 'Please accept the Terms and Privacy Policy';
    }

    if (error != null) {
      _toast(error);
      return;
    }

    setState(() => _busy = true);
    try {
      await AuthService.instance.signUpWithEmail(
        name: name,
        email: email,
        password: password,
      );
      if (!context.mounted) return;
      // Explicit nav: after a settings sign-out the _AuthGate is gone from the
      // stack, so push home and wipe the back stack rather than relying on the
      // gate rebuild.
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.home,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _toast(AuthService.describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _busy = true);
    try {
      final result = await AuthService.instance.signInWithGoogle();
      if (!mounted) return;
      if (result == null) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.home,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _toast(AuthService.describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
