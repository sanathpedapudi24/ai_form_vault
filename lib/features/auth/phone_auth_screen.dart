import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/fade_slide_in.dart';

/// Two-step phone sign-in: enter number → enter the OTP that's texted back.
/// On success the auth gate swaps this screen out automatically.
class PhoneAuthScreen extends ConsumerStatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  ConsumerState<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends ConsumerState<PhoneAuthScreen> {
  final _phone = TextEditingController(text: '+91');
  final _otp = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  String? _verificationId;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  AuthService get _auth => ref.read(authServiceProvider);

  Future<void> _sendCode() async {
    if (_busy) return;
    final number = _phone.text.trim();
    if (number.length < 8) {
      setState(() => _error = 'Enter your phone number with country code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await _auth.startPhoneVerification(
      phoneNumber: number,
      onCodeSent: (id) {
        if (!mounted) return;
        setState(() {
          _verificationId = id;
          _codeSent = true;
          _busy = false;
        });
      },
      onAutoVerified: () {
        // Gate swaps us out; nothing to do.
      },
      onError: (message) {
        if (mounted) {
          setState(() {
            _error = message;
            _busy = false;
          });
        }
      },
    );
  }

  Future<void> _confirm() async {
    if (_busy || _verificationId == null) return;
    if (_otp.text.trim().length < 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.confirmOtp(_verificationId!, _otp.text);
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_codeSent ? 'Enter code' : 'Phone sign-in'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: FadeSlideIn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _codeSent ? 'Check your messages' : 'What\'s your number?',
                  style: AppTextStyles.title,
                ),
                const Gap(6),
                Text(
                  _codeSent
                      ? 'We texted a 6-digit code to ${_phone.text.trim()}.'
                      : 'We\'ll text you a one-time code to verify it.',
                  style: AppTextStyles.bodySecondary,
                ),
                const Gap(24),
                if (!_codeSent)
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    style: AppTextStyles.body,
                    decoration: const InputDecoration(
                      hintText: '+91 98765 43210',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  )
                else
                  TextField(
                    controller: _otp,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofocus: true,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: AppTextStyles.title.copyWith(letterSpacing: 8),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      hintText: '000000',
                      counterText: '',
                    ),
                  ),
                if (_error != null) ...[
                  const Gap(8),
                  Text(
                    _error!,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const Gap(20),
                PrimaryButton(
                  label: _codeSent ? 'Verify' : 'Send code',
                  loading: _busy,
                  onPressed: _codeSent ? _confirm : _sendCode,
                ),
                if (_codeSent) ...[
                  const Gap(10),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _codeSent = false;
                              _otp.clear();
                              _error = null;
                            }),
                    child: Text(
                      'Change number',
                      style: AppTextStyles.buttonSmall
                          .copyWith(color: AppColors.textTertiary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
