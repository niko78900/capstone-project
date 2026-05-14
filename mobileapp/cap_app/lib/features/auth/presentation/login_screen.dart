import 'package:cap_app/app/app_router.dart';
import 'package:cap_app/core/errors/app_exception.dart';
import 'package:cap_app/core/errors/error_presenter.dart';
import 'package:cap_app/core/network/network_providers.dart';
import 'package:cap_app/features/auth/providers/auth_providers.dart';
import 'package:cap_app/features/settings/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(passwordResetGateProvider.notifier)
          .checkStoredStatus()
          .catchError((_) => null);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authSessionProvider);
    final debugModeEnabled = ref.watch(debugModeEnabledProvider);
    final isLoading = authState.isLoading;
    final authError = _resolveError(
      authState.asError?.error,
      debugModeEnabled: debugModeEnabled,
    );
    final fieldErrors = authError?.fieldErrors ?? const <String, String>{};
    final serverMessage = authError?.message;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Welcome Back',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to compare supermarket prices and submit updates.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        errorText: fieldErrors['email'],
                      ),
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return 'Email is required';
                        }
                        if (!trimmed.contains('@')) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        errorText: fieldErrors['password'],
                      ),
                      validator: (value) {
                        if ((value ?? '').isEmpty) {
                          return 'Password is required';
                        }
                        if ((value ?? '').length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _rememberMe,
                      onChanged: isLoading
                          ? null
                          : (value) {
                              setState(() {
                                _rememberMe = value ?? false;
                              });
                            },
                      title: const Text('Remember me?'),
                    ),
                    if (serverMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        serverMessage,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: isLoading ? null : _submit,
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Login'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              context.push(AppRoutes.register);
                            },
                      child: const Text('Create account'),
                    ),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              context.push(AppRoutes.forgotPassword);
                            },
                      child: const Text('Forgot password?'),
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref
        .read(authSessionProvider.notifier)
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    final state = ref.read(authSessionProvider);
    if (state.hasError) {
      return;
    }

    await _syncRememberedCredentials();
    if (mounted && state.valueOrNull != null) {
      context.go(AppRoutes.shop);
    }
  }

  Future<void> _loadRememberedCredentials() async {
    final storage = ref.read(authTokenStorageProvider);
    final remembered = await storage.readRememberedCredentials();
    if (!mounted || remembered == null) {
      return;
    }

    setState(() {
      _emailController.text = remembered.email;
      _passwordController.text = remembered.password;
      _rememberMe = true;
    });
  }

  Future<void> _syncRememberedCredentials() async {
    final storage = ref.read(authTokenStorageProvider);
    if (_rememberMe) {
      await storage.saveRememberedCredentials(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      return;
    }
    await storage.clearRememberedCredentials();
  }

  _AuthUiError? _resolveError(Object? error, {required bool debugModeEnabled}) {
    if (error == null) {
      return null;
    }

    if (error is AppException) {
      return _AuthUiError(
        message: formatErrorMessageForUi(
          error,
          debugModeEnabled: debugModeEnabled,
        ),
        fieldErrors: error.fieldErrors,
      );
    }

    return _AuthUiError(
      message: formatErrorMessageForUi(
        error,
        debugModeEnabled: debugModeEnabled,
      ),
    );
  }
}

class _AuthUiError {
  const _AuthUiError({required this.message, this.fieldErrors = const {}});

  final String message;
  final Map<String, String> fieldErrors;
}
