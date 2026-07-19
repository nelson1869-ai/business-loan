import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Validates development credentials and opens the dashboard on success.
///
/// File: `lib/features/auth/presentation/login_screen.dart`
///
/// Data Flow Diagram:
/// ```text
///  +--------------------+     +-------------------+     +-----------------------+
///  | splash_screen.dart | --> | login_screen.dart | --> | dashboard_screen.dart |
///  +--------------------+     +-------------------+     +-----------------------+
/// ```
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Development-only demo values. These are not production credentials.
  static const _demoUsername = 'officer1';
  static const _demoPassword = 'password123';

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController(
    text: kDebugMode ? _demoUsername : '',
  );
  final _passwordController = TextEditingController(
    text: kDebugMode ? _demoPassword : '',
  );
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    final isValidDemoLogin =
        kDebugMode &&
        _usernameController.text.trim() == _demoUsername &&
        _passwordController.text == _demoPassword;

    if (isValidDemoLogin) {
      context.go('/dashboard');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          kDebugMode
              ? 'Invalid development username or password.'
              : 'Authentication is not configured for this build.',
        ),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.account_balance,
                  size: 64,
                  color: Color(0xFF0D9488),
                ),
                const SizedBox(height: 16),
                Text(
                  'Welcome Back',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Log in to manage loan files in the field',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Development login is prefilled for classroom testing.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 32),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person_outline),
                    hintText: 'Enter your username',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Username is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    hintText: 'Enter your password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _handleLogin,
                  child: const Text('Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
