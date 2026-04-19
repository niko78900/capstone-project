import 'dart:io';

import 'package:cap_app/core/errors/app_exception.dart';
import 'package:cap_app/features/catalog/models/catalog_models.dart';
import 'package:cap_app/features/catalog/providers/catalog_providers.dart';
import 'package:cap_app/features/submissions/models/submission_models.dart';
import 'package:cap_app/features/submissions/providers/submission_providers.dart';
import 'package:cap_app/shared/widgets/android_back_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class SubmitProductScreen extends ConsumerStatefulWidget {
  const SubmitProductScreen({this.initialProduct, super.key});

  final ProductDetailDto? initialProduct;

  @override
  ConsumerState<SubmitProductScreen> createState() =>
      _SubmitProductScreenState();
}

class _SubmitProductScreenState extends ConsumerState<SubmitProductScreen> {
  static const _fixedServingSize = '100 g';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _priceController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _imagePicker = ImagePicker();

  int _categoryId = categoryOptions.first.id;
  int? _supermarketId;
  String? _imageUrl;
  String? _selectedImagePath;
  bool _isUploadingImage = false;
  String? _serverMessage;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    final initialProduct = widget.initialProduct;
    if (initialProduct == null) {
      return;
    }
    _categoryId = _resolveCategoryId(initialProduct.category);
    _nameController.text = initialProduct.name;
    _brandController.text = initialProduct.brand ?? '';
    _barcodeController.text = initialProduct.barcode ?? '';
    _imageUrl = initialProduct.imageUrl;
    if (initialProduct.prices.isNotEmpty) {
      final firstPrice = initialProduct.prices.first;
      _supermarketId = firstPrice.supermarketId;
      _priceController.text = _asNumberInput(firstPrice.price);
    }
    final nutrition = initialProduct.nutrition;
    if (nutrition != null) {
      _caloriesController.text = _asNumberInput(nutrition.calories);
      _proteinController.text = _asNumberInput(nutrition.proteinG);
      _carbsController.text = _asNumberInput(nutrition.carbsG);
      _fatController.text = _asNumberInput(nutrition.fatG);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supermarketsAsync = ref.watch(supermarketsProvider);
    final submitState = ref.watch(productSubmissionControllerProvider);
    final isSubmitting = submitState.isLoading;
    final isBusy = isSubmitting || _isUploadingImage;

    return BackToHomeScope(
      child: Scaffold(
        appBar: AppBar(title: const Text('Submit Product')),
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
                    onChanged: isBusy
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
                      labelText: 'Barcode',
                      errorText: _fieldErrors['barcode'],
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Barcode is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  supermarketsAsync.when(
                    data: (supermarkets) => _SupermarketDropdown(
                      supermarkets: supermarkets,
                      value: _supermarketId,
                      errorText: _fieldErrors['supermarketId'],
                      enabled: !isBusy,
                      onChanged: (value) {
                        final nextFieldErrors = Map<String, String>.from(
                          _fieldErrors,
                        );
                        nextFieldErrors.remove('supermarketId');
                        setState(() {
                          _supermarketId = value;
                          _fieldErrors = nextFieldErrors;
                        });
                      },
                    ),
                    loading: () =>
                        const _LoadingField(label: 'Loading supermarkets...'),
                    error: (error, _) => _ErrorField(
                      message: 'Failed to load supermarkets: $error',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Price (MKD)',
                      errorText: _fieldErrors['price'],
                    ),
                    validator: (value) {
                      final parsed = double.tryParse((value ?? '').trim());
                      if (parsed == null || parsed <= 0) {
                        return 'Price must be a positive number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: isBusy ? null : _chooseImageSource,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      ((_selectedImagePath == null ||
                                  _selectedImagePath!.trim().isEmpty) &&
                              (_imageUrl == null || _imageUrl!.trim().isEmpty))
                          ? 'Add an image'
                          : 'Change image',
                    ),
                  ),
                  if (_fieldErrors['imageUrl'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _fieldErrors['imageUrl']!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (_selectedImagePath != null &&
                      _selectedImagePath!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_selectedImagePath!),
                        fit: BoxFit.cover,
                        height: 180,
                        errorBuilder: (context, error, stackTrace) {
                          return const InputDecorator(
                            decoration: InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Selected image',
                            ),
                            child: Text('Unable to preview selected image.'),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: isBusy
                            ? null
                            : () {
                                setState(() {
                                  _selectedImagePath = null;
                                  _imageUrl = null;
                                });
                              },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove image'),
                      ),
                    ),
                  ] else if (_imageUrl != null &&
                      _imageUrl!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _imageUrl!,
                        fit: BoxFit.cover,
                        height: 180,
                        errorBuilder: (context, error, stackTrace) {
                          return InputDecorator(
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Selected image',
                            ),
                            child: Text(
                              _imageUrl!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: isBusy
                            ? null
                            : () {
                                setState(() {
                                  _selectedImagePath = null;
                                  _imageUrl = null;
                                });
                              },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove image'),
                      ),
                    ),
                  ],
                  if (_isUploadingImage) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 6),
                    const Text('Uploading image...'),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Nutrition per 100g',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _caloriesController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Calories',
                      errorText: _fieldErrors['nutrition.calories'],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _proteinController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Protein (g)',
                      errorText: _fieldErrors['nutrition.proteinG'],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _carbsController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Carbs (g)',
                      errorText: _fieldErrors['nutrition.carbsG'],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _fatController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Fat (g)',
                      errorText: _fieldErrors['nutrition.fatG'],
                    ),
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
                    onPressed: isBusy ? null : _submit,
                    child: isBusy
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
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_supermarketId == null) {
      setState(() {
        _fieldErrors = {
          ..._fieldErrors,
          'supermarketId': 'Supermarket is required',
        };
      });
      return;
    }

    setState(() {
      _serverMessage = null;
      _fieldErrors = const {};
    });

    String? imageUrl = _imageUrl;
    if (_selectedImagePath != null && _selectedImagePath!.trim().isNotEmpty) {
      setState(() {
        _isUploadingImage = true;
      });
      try {
        imageUrl = await ref
            .read(submissionRepositoryProvider)
            .uploadProductImage(_selectedImagePath!);
        if (!mounted) {
          return;
        }
        setState(() {
          _imageUrl = imageUrl;
          _selectedImagePath = null;
        });
      } catch (error) {
        if (!mounted) {
          return;
        }
        _applyError(error);
        return;
      } finally {
        if (mounted) {
          setState(() {
            _isUploadingImage = false;
          });
        }
      }
    }

    final calories = _toDouble(_caloriesController.text);
    final proteinG = _toDouble(_proteinController.text);
    final carbsG = _toDouble(_carbsController.text);
    final fatG = _toDouble(_fatController.text);
    final hasNutritionInput =
        calories != null || proteinG != null || carbsG != null || fatG != null;

    final request = ProductSubmissionRequestDto(
      categoryId: _categoryId,
      sourceProductId: widget.initialProduct?.id,
      name: _nameController.text.trim(),
      brand: _brandController.text,
      barcode: _barcodeController.text.trim(),
      supermarketId: _supermarketId!,
      price: double.parse(_priceController.text.trim()),
      imageUrl: imageUrl,
      nutrition: hasNutritionInput
          ? SubmissionNutritionInput(
              calories: calories,
              proteinG: proteinG,
              carbsG: carbsG,
              fatG: fatG,
              servingSize: _fixedServingSize,
            )
          : null,
    );

    final result = await ref
        .read(productSubmissionControllerProvider.notifier)
        .submit(request);
    if (result == null) {
      final error = ref
          .read(productSubmissionControllerProvider)
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
        content: Text('Product submission created and pending moderation.'),
      ),
    );
    _clearForm();
  }

  void _clearForm() {
    _nameController.clear();
    _brandController.clear();
    _barcodeController.clear();
    _priceController.clear();
    _caloriesController.clear();
    _proteinController.clear();
    _carbsController.clear();
    _fatController.clear();
    setState(() {
      _serverMessage = null;
      _fieldErrors = const {};
      _categoryId = categoryOptions.first.id;
      _supermarketId = null;
      _imageUrl = null;
      _selectedImagePath = null;
      _isUploadingImage = false;
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

  int _resolveCategoryId(String categoryName) {
    final normalized = categoryName.trim().toLowerCase();
    for (final option in categoryOptions) {
      if (option.name.toLowerCase() == normalized) {
        return option.id;
      }
    }
    return categoryOptions.first.id;
  }

  String _asNumberInput(double? value) {
    if (value == null) {
      return '';
    }
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  Future<void> _chooseImageSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || source == null) {
      return;
    }
    await _pickImage(source);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (!mounted || picked == null) {
        return;
      }
      final nextFieldErrors = Map<String, String>.from(_fieldErrors);
      nextFieldErrors.remove('imageUrl');
      setState(() {
        _selectedImagePath = picked.path;
        _imageUrl = null;
        _fieldErrors = nextFieldErrors;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _serverMessage = 'Could not access camera or gallery.';
      });
    }
  }
}

class _SupermarketDropdown extends StatelessWidget {
  const _SupermarketDropdown({
    required this.supermarkets,
    required this.value,
    required this.onChanged,
    required this.enabled,
    this.errorText,
  });

  final List<SupermarketDto> supermarkets;
  final int? value;
  final ValueChanged<int?> onChanged;
  final bool enabled;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: 'Supermarket',
        errorText: errorText,
      ),
      items: supermarkets
          .map(
            (market) => DropdownMenuItem<int>(
              value: market.id,
              child: Text(market.name),
            ),
          )
          .toList(),
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _LoadingField extends StatelessWidget {
  const _LoadingField({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(border: OutlineInputBorder()),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }
}

class _ErrorField extends StatelessWidget {
  const _ErrorField({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(border: OutlineInputBorder()),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
