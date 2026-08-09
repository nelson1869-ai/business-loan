import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

final securityConfirmationServiceProvider = Provider<SecurityConfirmationService>((ref) {
  return SecurityConfirmationService();
});

class SecurityConfirmationService {
  SecurityConfirmationService({
    LocalAuthentication? auth,
    FlutterSecureStorage? storage,
  })  : _auth = auth ?? LocalAuthentication(),
        _storage = storage ?? const FlutterSecureStorage();

  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;

  static const String _pinKey = 'admin_owner_pin';
  static const String _defaultPin = '1234';

  /// Check if biometric hardware is supported and enrolled on device
  Future<bool> isBiometricAvailable() async {
    try {
      final canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canAuthenticateWithBiometrics && isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  /// Attempt biometric authentication
  Future<bool> authenticateBiometric({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
      );
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Get stored owner PIN or default
  Future<String> getOwnerPin() async {
    final pin = await _storage.read(key: _pinKey);
    if (pin == null || pin.isEmpty) {
      await _storage.write(key: _pinKey, value: _defaultPin);
      return _defaultPin;
    }
    return pin;
  }

  /// Set new owner PIN
  Future<void> setOwnerPin(String newPin) async {
    await _storage.write(key: _pinKey, value: newPin);
  }

  /// Verify entered PIN against stored PIN
  Future<bool> verifyPin(String enteredPin) async {
    final storedPin = await getOwnerPin();
    return enteredPin.trim() == storedPin.trim();
  }

  /// Prompt owner for confirmation using Biometrics or PIN fallback
  Future<bool> promptOwnerConfirmation(
    BuildContext context, {
    required String title,
    required String description,
    String confirmLabel = 'Confirm Action',
  }) async {
    // 1. Try biometric auth if available
    final canBio = await isBiometricAvailable();
    if (canBio) {
      final success = await authenticateBiometric(reason: '$title: $description');
      if (success) return true;
    }

    // 2. Fallback to PIN Entry Modal
    if (!context.mounted) return false;
    final pinVerified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _AdminPinConfirmationDialog(
        title: title,
        description: description,
        confirmLabel: confirmLabel,
        service: this,
      ),
    );

    return pinVerified ?? false;
  }

  /// Alias for backward compatibility
  Future<bool> promptAdminConfirmation(
    BuildContext context, {
    required String title,
    required String description,
    String confirmLabel = 'Confirm Action',
  }) =>
      promptOwnerConfirmation(
        context,
        title: title,
        description: description,
        confirmLabel: confirmLabel,
      );
}

class _AdminPinConfirmationDialog extends StatefulWidget {
  const _AdminPinConfirmationDialog({
    required this.title,
    required this.description,
    required this.confirmLabel,
    required this.service,
  });

  final String title;
  final String description;
  final String confirmLabel;
  final SecurityConfirmationService service;

  @override
  State<_AdminPinConfirmationDialog> createState() =>
      __AdminPinConfirmationDialogState();
}

class __AdminPinConfirmationDialogState
    extends State<_AdminPinConfirmationDialog> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleConfirm() async {
    final pin = _pinController.text.trim();
    if (pin.length < 4) {
      setState(() => _errorMessage = 'Enter 4-digit security PIN');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final isValid = await widget.service.verifyPin(pin);
    if (!mounted) return;

    if (isValid) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Incorrect PIN (Default: 1234)';
        _pinController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_user,
              color: theme.colorScheme.onPrimaryContainer,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Owner Security PIN',
                hintText: 'Enter PIN (Default: 1234)',
                counterText: '',
                errorText: _errorMessage,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
              ),
              onSubmitted: (_) => _handleConfirm(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _handleConfirm,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
