import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/input_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/status_bar.dart';

/// LOGIN — Figma node 1:312. Wired to FirebaseAuth via [AuthService].
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || !email.contains('@')) {
      _toast('Enter a valid email address');
      return;
    }
    if (password.isEmpty) {
      _toast('Enter your password');
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthService.instance.signInWithEmail(
        email: email,
        password: password,
      );
      if (!mounted) return;
      // AuthGate routes us away automatically; pop anything pushed on top.
      Navigator.of(context).popUntil((r) => r.isFirst);
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
      if (result == null) return; // user cancelled
      Navigator.of(context).popUntil((r) => r.isFirst);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                const FakeStatusBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          'Welcome Back! 👋',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                            height: 1.05,
                            letterSpacing: 0.16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Please enter your login details.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textHint,
                          ),
                        ),
                        const SizedBox(height: 36),
                        LabeledField(
                          label: 'Email Address',
                          icon: Icons.email_outlined,
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 13),
                        LabeledField(
                          label: 'Password',
                          icon: Icons.lock_outline_rounded,
                          controller: _password,
                          obscureText: _obscure,
                          suffix: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppColors.textBody,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        const SizedBox(height: 9),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.forgotPassword,
                            ),
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        PrimaryButton(
                          label: _busy ? 'Signing in…' : 'Sign In',
                          onPressed: _busy ? null : _signIn,
                        ),
                        const SizedBox(height: 28),
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
                        const SizedBox(height: 18),
                        SocialButton(
                          label: 'Continue with Apple',
                          iconAsset: const Icon(Icons.apple,
                              color: Colors.black),
                          onPressed: _busy
                              ? null
                              : () => _toast(
                                  'Apple sign-in not configured yet.'),
                        ),
                        const SizedBox(height: 15),
                        SocialButton(
                          label: 'Continue with Google',
                          iconAsset: const _GoogleGlyph(),
                          onPressed: _busy ? null : _signInWithGoogle,
                        ),
                        const SizedBox(height: 32),
                        Center(
                          child: GestureDetector(
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.signup,
                            ),
                            child: RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 14,
                                ),
                                children: [
                                  TextSpan(text: 'Don’t have an account? '),
                                  TextSpan(
                                    text: 'Sign Up.',
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
            if (_busy)
              const Positioned.fill(
                child: IgnorePointer(
                  ignoring: false,
                  child: ColoredBox(color: Color(0x14000000)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Minimal Google "G" glyph — drawn rather than embedding the Figma raster.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 20),
      painter: _GooglePainter(),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paints = <Color, Paint>{
      const Color(0xFF4285F4): Paint()..color = const Color(0xFF4285F4),
      const Color(0xFF34A853): Paint()..color = const Color(0xFF34A853),
      const Color(0xFFFBBC05): Paint()..color = const Color(0xFFFBBC05),
      const Color(0xFFEA4335): Paint()..color = const Color(0xFFEA4335),
    };
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(rect, -1.57, 1.57, true, paints[const Color(0xFF4285F4)]!);
    canvas.drawArc(rect, 0, 1.57, true, paints[const Color(0xFF34A853)]!);
    canvas.drawArc(rect, 1.57, 1.57, true, paints[const Color(0xFFFBBC05)]!);
    canvas.drawArc(rect, 3.14, 1.57, true, paints[const Color(0xFFEA4335)]!);
    final cut = Paint()..color = Colors.white;
    canvas.drawCircle(c, r * 0.45, cut);
    final notch = Paint()..color = paints[const Color(0xFF4285F4)]!.color;
    canvas.drawRect(
      Rect.fromLTWH(c.dx, c.dy - 1.5, r, 3),
      notch,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
