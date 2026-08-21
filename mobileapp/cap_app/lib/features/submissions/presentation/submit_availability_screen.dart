// File purpose: Renders Flutter UI for submissions feature workflows.
import 'package:cap_app/core/errors/app_exception.dart';
import 'package:cap_app/core/errors/error_presenter.dart';
import 'package:cap_app/features/settings/providers/settings_providers.dart';
import 'package:cap_app/features/submissions/models/submission_models.dart';
import 'package:cap_app/features/submissions/providers/submission_providers.dart';
import 'package:cap_app/shared/widgets/android_back_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SubmitAvailabilityScreen extends ConsumerStatefulWidget {
  const SubmitAvailabilityScreen({
    required this.productId,
    required this.productName,
    required this.supermarketId,
    required this.supermarketName,
    super.key,
  });

  final int productId;
  final String productName;
  final int supermarketId;
  final String supermarketName;

  @override
  ConsumerState<SubmitAvailabilityScreen> createState() =>
      _SubmitAvailabilityScreenState();
}

class _SubmitAvailabilityScreenState
    extends ConsumerState<SubmitAvailabilityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  String? _serverMessage;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(availabilitySubmissionControllerProvider);
    final isSubmitting = submitState.isLoading;

    return BackToHomeScope(
      child: Scaffold(
        appBar: AppBar(title: const Text('Report availability')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.productName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text('Market: ${widget.supermarketName}'),
                        const SizedBox(height: 10),
                        const Text(
                          'This will create a moderation request to mark the item as not sold in this market anymore.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notesController,
                  enabled: !isSubmitting,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    labelText: 'Notes for moderator',
                    helperText: 'Optional. Example: shelf checked today.',
                    errorText: _fieldErrors['notes'],
                  ),
                  validator: (value) {
                    if ((value ?? '').length > 1000) {
                      return 'Notes must be at most 1000 characters';
                    }
                    return null;
                  },
                ),
                if (_serverMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _serverMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: isSubmitting ? null : _submit,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.block_outlined),
                  label: Text(
                    isSubmitting ? 'Submitting...' : 'Mark as not sold here',
                  ),
                ),
              ],
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

    final result = await ref
        .read(availabilitySubmissionControllerProvider.notifier)
        .submit(
          AvailabilitySubmissionRequestDto(
            productId: widget.productId,
            supermarketId: widget.supermarketId,
            available: false,
            notes: _notesController.text,
          ),
        );

    if (result == null) {
      final error = ref
          .read(availabilitySubmissionControllerProvider)
          .asError
          ?.error;
      if (error != null) {
        _applyError(error);
      }
      return;
    }

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Availability report created and pending moderation.'),
      ),
    );
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
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
