import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:borrower_mobile/core/auth/auth_notifier.dart';
import 'package:borrower_mobile/core/auth/auth_state.dart';
import 'package:borrower_mobile/core/widgets/app_button.dart';
import 'package:borrower_mobile/core/widgets/app_text_field.dart';
import 'package:borrower_mobile/core/widgets/route_back_navigation.dart';

class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    final success = await ref.read(authNotifierProvider.notifier).activateWithCode(
          phoneNumber: phone,
          activationCode: code,
          newPin: pin,
          confirmPin: confirmPin,
        );

    if (success && mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.authenticating;

    return RouteBackScope(
      fallbackLocation: '/login',
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Account Activation'),
          leading: const RouteBackButton(
            fallbackLocation: '/login',
            tooltip: 'Back to login',
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCCFBF1),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF99F6E4)),
                      ),
                      child: const Icon(
                        Icons.vpn_key_outlined,
                        size: 44,
                        color: Color(0xFF0D9488),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Activate Borrower Account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter your mobile number, activation code, and create your 4 to 6 digit security PIN.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 28),
                    AppTextField(
                      controller: _phoneController,
                      label: 'Mobile Number',
                      hint: '09171234567',
                      keyboardType: TextInputType.phone,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your registered mobile number.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _codeController,
                      label: '6-Digit Activation Code',
                      hint: '123456',
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      validator: (val) {
                        if (val == null || val.trim().length != 6) {
                          return 'Please enter the 6-digit code.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _pinController,
                      label: 'Create New PIN',
                      hint: '4 to 6 digits',
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      validator: (val) {
                        if (val == null || val.trim().length < 4) {
                          return 'PIN must be at least 4 digits.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _confirmPinController,
                      label: 'Confirm New PIN',
                      hint: 'Re-enter your PIN',
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      validator: (val) {
                        if (val == null || val.trim() != _pinController.text.trim()) {
                          return 'PINs do not match.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (authState.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Text(
                          authState.errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFF991B1B),
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    AppButton(
                      text: 'Activate Account & Continue',
                      isLoading: isLoading,
                      onPressed: _activate,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Back to Login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
