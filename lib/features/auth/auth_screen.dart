import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/fade_slide_in.dart';
import 'phone_auth_screen.dart';

/// Mandatory sign-in gate shown before the vault opens. Email/Password with
/// a Google option and a route into phone sign-in.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSignUp = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  AuthService get _auth => ref.read(authServiceProvider);

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      // On success the authStateProvider flips and the gate swaps this out.
    } on AuthException catch (e) {
      if (!e.cancelled && mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submitEmail() {
    if (!_formKey.currentState!.validate()) return;
    _run(() => _isSignUp
        ? _auth.signUpWithEmail(_email.text, _password.text)
        : _auth.signInWithEmail(_email.text, _password.text));
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email first, then tap reset.');
      return;
    }
    await _run(() => _auth.sendPasswordReset(email));
    if (mounted && _error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: FadeSlideIn(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.document_scanner_outlined,
                      color: AppColors.textOnAccent,
                      size: 28,
                    ),
                  ),
                  const Gap(24),
                  Text(
                    _isSignUp ? 'Create your account' : 'Welcome back',
                    style: AppTextStyles.display,
                  ),
                  const Gap(6),
                  Text(
                    _isSignUp
                        ? 'One account secures your vault across devices.'
                        : 'Sign in to unlock your vault.',
                    style: AppTextStyles.bodySecondary,
                  ),
                  const Gap(28),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    style: AppTextStyles.body,
                    decoration: const InputDecoration(
                      hintText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const Gap(12),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'At least 6 characters'
                        : null,
                  ),
                  if (!_isSignUp)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _busy ? null : _forgotPassword,
                        child: Text(
                          'Forgot password?',
                          style: AppTextStyles.buttonSmall
                              .copyWith(color: AppColors.textTertiary),
                        ),
                      ),
                    ),
                  if (_error != null) ...[
                    const Gap(6),
                    Text(
                      _error!,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const Gap(16),
                  PrimaryButton(
                    label: _isSignUp ? 'Create account' : 'Sign in',
                    loading: _busy,
                    onPressed: _submitEmail,
                  ),
                  const Gap(20),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or', style: AppTextStyles.caption),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const Gap(20),
                  SecondaryButton(
                    label: 'Continue with Google',
                    icon: Icons.g_mobiledata_rounded,
                    onPressed: _busy
                        ? null
                        : () => _run(_auth.signInWithGoogle),
                  ),
                  const Gap(10),
                  SecondaryButton(
                    label: 'Continue with phone',
                    icon: Icons.phone_outlined,
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PhoneAuthScreen(),
                              ),
                            ),
                  ),
                  const Gap(24),
                  Center(
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _isSignUp = !_isSignUp;
                                _error = null;
                              }),
                      child: Text.rich(
                        TextSpan(
                          text: _isSignUp
                              ? 'Already have an account? '
                              : 'New here? ',
                          style: AppTextStyles.bodySecondary,
                          children: [
                            TextSpan(
                              text: _isSignUp ? 'Sign in' : 'Create an account',
                              style: AppTextStyles.buttonSmall
                                  .copyWith(color: AppColors.accentDeep),
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
        ),
      ),
    );
  }
}
