import 'package:cap_app/core/errors/app_exception.dart';
import 'package:cap_app/features/submissions/models/submission_models.dart';
import 'package:cap_app/features/submissions/providers/submission_providers.dart';
import 'package:cap_app/shared/widgets/main_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SubmitProductScreen extends ConsumerStatefulWidget {
  const SubmitProductScreen({super.key});

  @override
  ConsumerState<SubmitProductScreen> createState() => _SubmitProductScreenState();
}

class _SubmitProductScreenState extends ConsumerState<SubmitProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _notesController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _servingController = TextEditingController();

  int _categoryId = categoryOptions.first.id;
  String? _serverMessage;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _barcodeController.dispose();
    _imageUrlController.dispose();
    _notesController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _servingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(productSubmissionControllerProvider);
    final isSubmitting = submitState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Submit Product')),
      drawer: const MainDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _categoryId,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    errorText: _fieldErrors['categoryId'],
                  ),
                  items: categoryOptions
                      .map(
                        (option) => DropdownMenuItem<int>(
                          value: option.id,
                          child: Text(option.name),
                        ),
                      )
                      .toList(),
                  onChanged: isSubmitting
                      ? null
                      : (value) {
                          setState(() {
                            _categoryId = value ?? _categoryId;
                          });
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Product name',
                    errorText: _fieldErrors['name'],
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Product name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _brandController,
                  decoration: InputDecoration(
                    labelText: 'Brand (optional)',
                    errorText: _fieldErrors['brand'],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _barcodeController,
                  decoration: InputDecoration(
                    labelText: 'Barcode (optional)',
                    errorText: _fieldErrors['barcode'],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _imageUrlController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'Image URL (optional)',
                    errorText: _fieldErrors['imageUrl'],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Nutrition (optional)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _caloriesController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Calories',
                    errorText: _fieldErrors['nutrition.calories'],
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _proteinController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Protein (g)',
                    errorText: _fieldErrors['nutrition.proteinG'],
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _carbsController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Carbs (g)',
                    errorText: _fieldErrors['nutrition.carbsG'],
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _fatController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Fat (g)',
                    errorText: _fieldErrors['nutrition.fatG'],
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _servingController,
                  decoration: InputDecoration(
                    labelText: 'Serving size',
                    errorText: _fieldErrors['nutrition.servingSize'],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Notes (optional)',
                    errorText: _fieldErrors['notes'],
                  ),
                ),
                if (_serverMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _serverMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: isSubmitting ? null : _submit,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit product proposal'),
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

    final request = ProductSubmissionRequestDto(
      categoryId: _categoryId,
      name: _nameController.text.trim(),
      brand: _brandController.text,
      barcode: _barcodeController.text,
      imageUrl: _imageUrlController.text,
      nutrition: SubmissionNutritionInput(
        calories: _toDouble(_caloriesController.text),
        proteinG: _toDouble(_proteinController.text),
        carbsG: _toDouble(_carbsController.text),
        fatG: _toDouble(_fatController.text),
        servingSize: _servingController.text,
      ),
      notes: _notesController.text,
    );

    final result = await ref.read(productSubmissionControllerProvider.notifier).submit(request);
    if (result == null) {
      final error = ref.read(productSubmissionControllerProvider).asError?.error;
      if (error != null) {
        _applyError(error);
      }
      return;
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Product submission created and pending moderation.')),
    );
    _clearForm();
  }

  void _clearForm() {
    _nameController.clear();
    _brandController.clear();
    _barcodeController.clear();
    _imageUrlController.clear();
    _notesController.clear();
    _caloriesController.clear();
    _proteinController.clear();
    _carbsController.clear();
    _fatController.clear();
    _servingController.clear();
    setState(() {
      _serverMessage = null;
      _fieldErrors = const {};
      _categoryId = categoryOptions.first.id;
    });
    ref.read(productSubmissionControllerProvider.notifier).clear();
  }

  void _applyError(Object error) {
    if (error is AppException) {
      setState(() {
        _serverMessage = error.message;
        _fieldErrors = error.fieldErrors;
      });
      return;
    }
    setState(() {
      _serverMessage = 'Could not submit product right now.';
      _fieldErrors = const {};
    });
  }

  double? _toDouble(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return double.tryParse(trimmed);
  }
}
