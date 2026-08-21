// File purpose: Renders Flutter UI for auth feature workflows.
import 'package:cap_app/app/app_router.dart';
import 'package:cap_app/core/errors/app_exception.dart';
import 'package:cap_app/core/errors/error_presenter.dart';
import 'package:cap_app/features/auth/providers/auth_providers.dart';
import 'package:cap_app/features/settings/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _serverMessage;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authSessionProvider);
    final isLoading = authState.isLoading;

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
                      'Create Account',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Register to browse products, compare carts, and submit price updates.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Display name',
                        errorText: _fieldErrors['displayName'],
                      ),
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return 'Display name is required';
                        }
                        if (trimmed.length < 2) {
                          return 'Display name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        errorText: _fieldErrors['email'],
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
                        errorText: _fieldErrors['password'],
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
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                      ),
                      validator: (value) {
                        if ((value ?? '').isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    if (_serverMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _serverMessage!,
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
                          : const Text('Register'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go(AppRoutes.login);
                              }
                            },
                      child: const Text('Back to login'),
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

    setState(() {
      _serverMessage = null;
      _fieldErrors = const {};
    });

    await ref
        .read(authSessionProvider.notifier)
        .register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
        );

    final state = ref.read(authSessionProvider);
    final error = state.asError?.error;
    if (error != null) {
      _applyError(error);
      return;
    }

    if (mounted) {
      context.go(AppRoutes.shop);
    }
  }

  void _applyError(Object error) {
    final debugModeEnabled = ref.read(debugModeEnabledProvider);
    if (error is AppException) {
      setState(() {
        _serverMessage = formatErrorMessageForUi(
          error,
          debugModeEnabled: debugModeEnabled,
        );
        _fieldErrors = error.fieldErrors;
      });
      return;
    }

    setState(() {
      _serverMessage = formatErrorMessageForUi(
        error,
        debugModeEnabled: debugModeEnabled,
      );
      _fieldErrors = const {};
    });
  }
}
