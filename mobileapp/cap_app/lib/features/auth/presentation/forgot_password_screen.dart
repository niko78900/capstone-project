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

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _checkingStatus = false;
  String? _message;
  String? _statusError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkStatus(showPendingMessage: false);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requestState = ref.watch(passwordResetRequestControllerProvider);
    final debugModeEnabled = ref.watch(debugModeEnabledProvider);
    final isLoading = requestState.isLoading || _checkingStatus;
    final requestError = _resolveError(
      requestState.asError?.error,
      debugModeEnabled: debugModeEnabled,
    );
    final errorMessage = requestError ?? _statusError;

    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
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
                      'Request a reset',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your account email. An admin will approve or deny the request.',
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
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(_message!),
                    ],
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
                      child: requestState.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Request reset'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: isLoading ? null : () => _checkStatus(),
                      child: Text(
                        _checkingStatus
                            ? 'Checking...'
                            : 'Check request status',
                      ),
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _message = null;
      _statusError = null;
    });

    final response = await ref
        .read(passwordResetRequestControllerProvider.notifier)
        .request(_emailController.text.trim());
    if (!mounted || response == null) {
      return;
    }

    final expiry = response.expiresAt == null
        ? 'within 24 hours'
        : 'by ${MaterialLocalizations.of(context).formatFullDate(response.expiresAt!.toLocal())}';
    await ref
        .read(passwordResetGateProvider.notifier)
        .checkStoredStatus(showNotification: false)
        .catchError((_) => null);
    setState(() {
      _message = 'Request sent for admin review. Check back $expiry.';
    });
  }

  Future<void> _checkStatus({bool showPendingMessage = true}) async {
    if (_checkingStatus) {
      return;
    }
    setState(() {
      _checkingStatus = true;
      _statusError = null;
    });
    try {
      final status = await ref
          .read(passwordResetGateProvider.notifier)
          .checkStoredStatus();
      if (!mounted) {
        return;
      }
      if (status == null) {
        if (showPendingMessage) {
          setState(() {
            _message = 'No password reset request is stored on this device.';
          });
        }
        return;
      }
      switch (status.status) {
        case PasswordResetStatus.approved:
          context.go(AppRoutes.resetPassword);
          break;
        case PasswordResetStatus.denied:
          setState(() {
            _message = 'Your password reset request was denied.';
          });
          break;
        case PasswordResetStatus.completed:
        case PasswordResetStatus.expired:
          setState(() {
            _message = status.status == PasswordResetStatus.expired
                ? 'Your reset request expired. Submit a new request if needed.'
                : 'Password reset completed. Please log in.';
          });
          break;
        case PasswordResetStatus.pending:
        case PasswordResetStatus.unknown:
          if (showPendingMessage) {
            setState(() {
              _message =
                  'Your reset request is still waiting for admin review.';
            });
          }
          break;
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusError = _resolveError(
          error,
          debugModeEnabled: ref.read(debugModeEnabledProvider),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _checkingStatus = false;
        });
      }
    }
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
