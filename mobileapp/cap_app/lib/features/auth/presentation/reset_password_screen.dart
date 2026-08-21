// File purpose: Renders Flutter UI for auth feature workflows.
import 'package:cap_app/app/app_router.dart';
import 'package:cap_app/core/errors/app_exception.dart';
import 'package:cap_app/core/errors/error_presenter.dart';
import 'package:cap_app/features/auth/models/password_reset_models.dart';
import 'package:cap_app/features/auth/providers/auth_providers.dart';
import 'package:cap_app/features/settings/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadApprovedEmail();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resetState = ref.watch(passwordResetCompletionControllerProvider);
    final debugModeEnabled = ref.watch(debugModeEnabledProvider);
    final errorMessage = _resolveError(
      resetState.asError?.error,
      debugModeEnabled: debugModeEnabled,
    );
    final isLoading = resetState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
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
                      'Set a new password',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use the same email that created the approved reset request.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
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
                      decoration: const InputDecoration(
                        labelText: 'New password',
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
                      controller: _confirmController,
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
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage,
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
                          : const Text('Set new password'),
                    ),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () => context.go(AppRoutes.login),
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

  Future<void> _loadApprovedEmail() async {
    try {
      final status =
          ref.read(passwordResetGateProvider).valueOrNull ??
          await ref
              .read(passwordResetGateProvider.notifier)
              .checkStoredStatus(showNotification: false);
      if (!mounted ||
          status == null ||
          status.status != PasswordResetStatus.approved) {
        return;
      }
      setState(() {
        _emailController.text = status.email;
      });
    } catch (_) {
      // The submit flow will show the actionable error if the stored token is invalid.
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final response = await ref
        .read(passwordResetCompletionControllerProvider.notifier)
        .complete(
          email: _emailController.text.trim(),
          newPassword: _passwordController.text,
        );
    if (!mounted || response == null) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(response.message)));
    context.go(AppRoutes.login);
  }

  String? _resolveError(Object? error, {required bool debugModeEnabled}) {
    if (error == null) {
      return null;
    }
    if (error is AppException) {
      return formatErrorMessageForUi(error, debugModeEnabled: debugModeEnabled);
    }
    return formatErrorMessageForUi(error, debugModeEnabled: debugModeEnabled);
  }
}
