import 'dart:io';

import 'package:cap_app/app/app_router.dart';
import 'package:cap_app/core/errors/app_exception.dart';
import 'package:cap_app/core/errors/error_presenter.dart';
import 'package:cap_app/features/catalog/models/catalog_models.dart';
import 'package:cap_app/features/catalog/presentation/barcode_scanner_screen.dart';
import 'package:cap_app/features/catalog/providers/catalog_providers.dart';
import 'package:cap_app/features/catalog/utils/barcode_resolution.dart';
import 'package:cap_app/features/settings/providers/settings_providers.dart';
import 'package:cap_app/features/submissions/models/submission_models.dart';
import 'package:cap_app/features/submissions/providers/submission_providers.dart';
import 'package:cap_app/features/submissions/utils/ai_draft_merge.dart';
import 'package:cap_app/features/submissions/utils/submission_flow_helpers.dart';
import 'package:cap_app/shared/widgets/android_back_scope.dart';
import 'package:cap_app/shared/widgets/barcode_asset_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class GuidedProductSubmissionScreen extends ConsumerStatefulWidget {
  const GuidedProductSubmissionScreen({this.prefillBarcode, super.key});

  final String? prefillBarcode;

  @override
  ConsumerState<GuidedProductSubmissionScreen> createState() =>
      _GuidedProductSubmissionScreenState();
}

class _GuidedProductSubmissionScreenState
    extends ConsumerState<GuidedProductSubmissionScreen> {
  static const _fixedServingSize = '100 g';

  final _reviewFormKey = GlobalKey<FormState>();
  final _barcodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _priceController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _imagePicker = ImagePicker();

  int _stepIndex = 0;
  int? _categoryId;
  int? _supermarketId;
  ProductSummaryDto? _duplicateProduct;
  String? _priceImagePath;
  String? _nutritionImagePath;
  String? _productImagePath;
  String? _imageUrl;
  bool _nutritionSkipped = false;
  bool _barcodeReady = false;
  bool _isCheckingBarcode = false;
  bool _isApplyingAiDraft = false;
  bool _isUploadingImage = false;
  String? _verifiedBarcode;
  String? _serverMessage;
  String? _stepMessage;
  String? _categoryMessage;
  Map<String, String> _fieldErrors = const {};
  List<String> _aiWarnings = const [];
  List<String> _aiFlags = const [];

  @override
  void initState() {
    super.initState();
    final prefill = normalizeBarcodeInput(widget.prefillBarcode ?? '');
    if (prefill.isNotEmpty) {
      _barcodeController.text = prefill;
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(productSubmissionControllerProvider);
    final isSubmitting = submitState.isLoading;
    final isBusy =
        isSubmitting ||
        _isCheckingBarcode ||
        _isApplyingAiDraft ||
        _isUploadingImage;

    return BackToHomeScope(
      child: Scaffold(
        appBar: AppBar(title: const Text('Guided Product Submission')),
        body: SafeArea(
          child: Stepper(
            currentStep: _stepIndex,
            onStepTapped: isBusy ? null : _handleStepTapped,
            controlsBuilder: (context, details) => const SizedBox.shrink(),
            steps: [
              Step(
                title: const Text('Barcode'),
                isActive: _stepIndex == 0,
                state: _barcodeReady ? StepState.complete : StepState.indexed,
                content: _buildBarcodeStep(isBusy),
              ),
              Step(
                title: const Text('Price'),
                isActive: _stepIndex == 1,
                state: _priceStepComplete
                    ? StepState.complete
                    : StepState.indexed,
                content: _buildPriceStep(isBusy),
              ),
              Step(
                title: const Text('Nutrition'),
                isActive: _stepIndex == 2,
                state: _nutritionStepComplete
                    ? StepState.complete
                    : StepState.indexed,
                content: _buildNutritionStep(isBusy),
              ),
              Step(
                title: const Text('Review'),
                isActive: _stepIndex == 3,
                state: StepState.indexed,
                content: _buildReviewStep(isBusy),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _priceStepComplete {
    return _priceController.text.trim().isNotEmpty ||
        (_priceImagePath ?? '').trim().isNotEmpty;
  }

  bool get _nutritionStepComplete {
    return _nutritionSkipped ||
        (_nutritionImagePath ?? '').trim().isNotEmpty ||
        _hasNutritionInput;
  }

  bool get _hasNutritionInput {
    return parseOptionalDouble(_caloriesController.text) != null ||
        parseOptionalDouble(_proteinController.text) != null ||
        parseOptionalDouble(_carbsController.text) != null ||
        parseOptionalDouble(_fatController.text) != null;
  }

  void _handleStepTapped(int index) {
    if (index == 0 || index < _stepIndex) {
      setState(() => _stepIndex = index);
      return;
    }
    if (index == 1 && _barcodeReady) {
      setState(() => _stepIndex = index);
      return;
    }
    if (index == 2 && _priceStepComplete) {
      setState(() => _stepIndex = index);
      return;
    }
    if (index == 3 && _priceStepComplete && _nutritionStepComplete) {
      setState(() => _stepIndex = index);
    }
  }

  Widget _buildBarcodeStep(bool isBusy) {
    final duplicate = _duplicateProduct;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _barcodeController,
          enabled: !isBusy,
          decoration: const InputDecoration(
            labelText: 'Scanned barcode',
            helperText: 'Scan first, then confirm the detected code.',
          ),
          onChanged: (_) => setState(() {
            _barcodeReady = false;
            _verifiedBarcode = null;
            _duplicateProduct = null;
          }),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : _scanBarcode,
                icon: const BarcodeAssetIcon(size: 22),
                label: Text(
                  _barcodeController.text.trim().isEmpty
                      ? 'Scan barcode'
                      : 'Rescan',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: isBusy ? null : _confirmBarcode,
                icon: _isCheckingBarcode
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_outlined),
                label: const Text('Confirm'),
              ),
            ),
          ],
        ),
        if (_stepMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            _stepMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (duplicate != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Product already exists',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text('${duplicate.name} - ${duplicate.brand ?? 'Unbranded'}'),
                  Text('Category: ${duplicate.category}'),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () => context.push(
                      AppRoutes.submitPrice,
                      extra: duplicate.id,
                    ),
                    icon: const Icon(Icons.price_change_outlined),
                    label: const Text('Submit price update'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: isBusy ? null : _scanBarcode,
                    icon: const BarcodeAssetIcon(size: 22),
                    label: const Text('Scan again'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPriceStep(bool isBusy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _priceController,
          enabled: !isBusy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Price (MKD)',
            helperText: 'Type the price or capture a price tag photo.',
          ),
        ),
        const SizedBox(height: 10),
        _ImageCaptureTile(
          label: 'Price tag photo',
          path: _priceImagePath,
          enabled: !isBusy,
          onCapture: () => _captureImage((path) {
            _priceImagePath = path;
          }),
          onRemove: () => setState(() => _priceImagePath = null),
        ),
        if (_stepMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            _stepMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: isBusy ? null : _continueFromPrice,
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildNutritionStep(bool isBusy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ImageCaptureTile(
          label: 'Nutrition values photo',
          path: _nutritionImagePath,
          enabled: !isBusy,
          onCapture: () => _captureImage((path) {
            _nutritionImagePath = path;
            _nutritionSkipped = false;
          }),
          onRemove: () => setState(() => _nutritionImagePath = null),
        ),
        const SizedBox(height: 12),
        Text(
          'Nutrition per 100g',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _caloriesController,
          enabled: !isBusy && !_nutritionSkipped,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Calories'),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _proteinController,
          enabled: !isBusy && !_nutritionSkipped,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Protein (g)'),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _carbsController,
          enabled: !isBusy && !_nutritionSkipped,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Carbs (g)'),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _fatController,
          enabled: !isBusy && !_nutritionSkipped,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Fat (g)'),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _nutritionSkipped,
          onChanged: isBusy
              ? null
              : (value) {
                  setState(() {
                    _nutritionSkipped = value ?? false;
                    if (_nutritionSkipped) {
                      _nutritionImagePath = null;
                      _caloriesController.clear();
                      _proteinController.clear();
                      _carbsController.clear();
                      _fatController.clear();
                    }
                  });
                },
          title: const Text('Nutrition unavailable'),
        ),
        if (_stepMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            _stepMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: isBusy ? null : _continueFromNutrition,
          child: _isApplyingAiDraft
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create draft'),
        ),
      ],
    );
  }

  Widget _buildReviewStep(bool isBusy) {
    final supermarketsAsync = ref.watch(supermarketsProvider);
    final debugModeEnabled = ref.watch(debugModeEnabledProvider);

    return Form(
      key: _reviewFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_categoryMessage != null) ...[
            _InlineMessage(
              message: _categoryMessage!,
              color: Theme.of(context).colorScheme.tertiary,
            ),
            const SizedBox(height: 10),
          ],
          if (_aiWarnings.isNotEmpty) ...[
            _InlineMessageList(
              title: 'AI Warnings',
              items: _aiWarnings,
              color: Theme.of(context).colorScheme.tertiary,
            ),
            const SizedBox(height: 10),
          ],
          if (_aiFlags.isNotEmpty) ...[
            _InlineMessageList(
              title: 'AI Flags',
              items: _aiFlags,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 10),
          ],
          TextFormField(
            controller: _barcodeController,
            enabled: !isBusy,
            decoration: InputDecoration(
              labelText: 'Barcode',
              errorText: _fieldErrors['barcode'],
              suffixIcon: IconButton(
                tooltip: 'Rescan barcode',
                onPressed: isBusy ? null : _scanBarcode,
                icon: const BarcodeAssetIcon(size: 24),
              ),
            ),
            onChanged: (_) => setState(() {
              _barcodeReady = false;
              _verifiedBarcode = null;
              _duplicateProduct = null;
            }),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Barcode is required' : null,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            key: ValueKey('category-$_categoryId'),
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
                      _categoryId = value;
                      _categoryMessage = null;
                    });
                  },
            validator: (value) => value == null ? 'Category is required' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _nameController,
            enabled: !isBusy,
            decoration: InputDecoration(
              labelText: 'Product name',
              errorText: _fieldErrors['name'],
            ),
            validator: (value) => (value ?? '').trim().isEmpty
                ? 'Product name is required'
                : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _brandController,
            enabled: !isBusy,
            decoration: InputDecoration(
              labelText: 'Brand (optional)',
              errorText: _fieldErrors['brand'],
            ),
          ),
          const SizedBox(height: 10),
          supermarketsAsync.when(
            data: (supermarkets) => DropdownButtonFormField<int>(
              key: ValueKey('market-$_supermarketId'),
              initialValue: _supermarketId,
              decoration: InputDecoration(
                labelText: 'Market',
                errorText: _fieldErrors['supermarketId'],
              ),
              items: supermarkets
                  .map(
                    (market) => DropdownMenuItem<int>(
                      value: market.id,
                      child: Text(market.name),
                    ),
                  )
                  .toList(),
              onChanged: isBusy
                  ? null
                  : (value) => setState(() => _supermarketId = value),
              validator: (value) => value == null ? 'Market is required' : null,
            ),
            loading: () => const _LoadingField(label: 'Loading markets...'),
            error: (error, _) => _ErrorField(
              message: formatErrorMessageForUi(
                error,
                debugModeEnabled: debugModeEnabled,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _priceController,
            enabled: !isBusy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          const SizedBox(height: 14),
          _ImageCaptureTile(
            label: 'Product listing photo',
            path: _productImagePath,
            enabled: !isBusy,
            onCapture: () => _captureImage((path) {
              _productImagePath = path;
              _imageUrl = null;
            }),
            onRemove: () => setState(() {
              _productImagePath = null;
              _imageUrl = null;
            }),
          ),
          if (_productImagePath != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(_productImagePath!),
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Text('Unable to preview selected image.'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Nutrition per 100g',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _caloriesController,
            enabled: !isBusy && !_nutritionSkipped,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Calories',
              errorText: _fieldErrors['nutrition.calories'],
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _proteinController,
            enabled: !isBusy && !_nutritionSkipped,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Protein (g)',
              errorText: _fieldErrors['nutrition.proteinG'],
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _carbsController,
            enabled: !isBusy && !_nutritionSkipped,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Carbs (g)',
              errorText: _fieldErrors['nutrition.carbsG'],
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _fatController,
            enabled: !isBusy && !_nutritionSkipped,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Fat (g)',
              errorText: _fieldErrors['nutrition.fatG'],
            ),
          ),
          if (_serverMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _serverMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: isBusy ? null : _applyAiDraftsIfAvailable,
            icon: const Icon(Icons.smart_toy_outlined),
            label: const Text('Refresh AI suggestions'),
          ),
          const SizedBox(height: 10),
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
    );
  }

  Future<void> _scanBarcode() async {
    final scannedValue = await scanBarcodeWithDevice(context);
    if (!mounted) {
      return;
    }
    final normalized = normalizeBarcodeInput(scannedValue ?? '');
    if (normalized.isEmpty) {
      return;
    }
    setState(() {
      _barcodeController.text = normalized;
      _duplicateProduct = null;
      _barcodeReady = false;
      _verifiedBarcode = null;
      _stepMessage = null;
      _stepIndex = 0;
    });
  }

  Future<void> _confirmBarcode() async {
    final normalized = normalizeBarcodeInput(_barcodeController.text);
    if (normalized.isEmpty) {
      setState(() => _stepMessage = 'Scan or enter a barcode first.');
      return;
    }

    setState(() {
      _isCheckingBarcode = true;
      _stepMessage = null;
      _duplicateProduct = null;
      _barcodeController.text = normalized;
    });

    try {
      final results = await ref
          .read(catalogRepositoryProvider)
          .getProducts(query: normalized);
      if (!mounted) {
        return;
      }
      final duplicate = findExactBarcodeMatch(
        scannedValue: normalized,
        searchResults: results,
      );
      setState(() {
        _duplicateProduct = duplicate;
        _barcodeReady = duplicate == null;
        _verifiedBarcode = duplicate == null ? normalized : null;
        _isCheckingBarcode = false;
        if (duplicate == null) {
          _stepIndex = 1;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isCheckingBarcode = false;
        _barcodeReady = false;
        _verifiedBarcode = null;
        _stepMessage = formatErrorMessageForUi(
          error,
          debugModeEnabled: ref.read(debugModeEnabledProvider),
        );
      });
    }
  }

  void _continueFromPrice() {
    if (!_priceStepComplete) {
      setState(() {
        _stepMessage = 'Enter a price or capture the price tag first.';
      });
      return;
    }
    setState(() {
      _stepMessage = null;
      _stepIndex = 2;
    });
  }

  Future<void> _continueFromNutrition() async {
    if (!_nutritionStepComplete) {
      setState(() {
        _stepMessage =
            'Add nutrition values, capture nutrition, or mark it unavailable.';
      });
      return;
    }
    setState(() => _stepMessage = null);
    await _applyAiDraftsIfAvailable();
    if (!mounted) {
      return;
    }
    setState(() => _stepIndex = 3);
  }

  Future<void> _applyAiDraftsIfAvailable() async {
    final captures = <AiCaptureType, String>{
      if ((_priceImagePath ?? '').trim().isNotEmpty)
        AiCaptureType.price: _priceImagePath!,
      if ((_nutritionImagePath ?? '').trim().isNotEmpty)
        AiCaptureType.nutrition: _nutritionImagePath!,
    };

    if (captures.isEmpty) {
      setState(() {
        _categoryId ??= null;
        _categoryMessage = 'Select a category manually.';
      });
      return;
    }

    setState(() {
      _isApplyingAiDraft = true;
      _aiWarnings = const [];
      _aiFlags = const [];
      _serverMessage = null;
    });

    final repository = ref.read(submissionRepositoryProvider);
    final drafts = <AiCaptureType, ProductAiDraftResponseDto>{};
    final warnings = <String>{};

    for (final entry in captures.entries) {
      try {
        final draft = await repository.draftProductFromUpload(
          entry.value,
          captureType: entry.key,
        );
        drafts[entry.key] = draft;
      } catch (error) {
        warnings.add(
          '${entry.key.label}: ${formatErrorMessageForUi(error, debugModeEnabled: ref.read(debugModeEnabledProvider))}',
        );
      }
    }

    if (!mounted) {
      return;
    }

    if (drafts.isEmpty) {
      setState(() {
        _isApplyingAiDraft = false;
        _aiWarnings = warnings.toList();
        _categoryMessage = 'Select a category manually.';
      });
      return;
    }

    final merged = mergeAiDraftResponses(
      responsesByType: drafts,
      skippedTypes: {
        if (!captures.containsKey(AiCaptureType.price)) AiCaptureType.price,
        if (!captures.containsKey(AiCaptureType.nutrition))
          AiCaptureType.nutrition,
      },
    );
    final categoryResolution = resolveCategoryHint(
      categoryHint: merged.categoryHint,
      drafts: drafts.values,
    );

    setState(() {
      _applyMergedSuggestion(merged, categoryResolution.categoryId);
      warnings.addAll(merged.warnings);
      _aiWarnings = warnings.toList();
      _aiFlags = merged.flags;
      _categoryMessage = categoryResolution.message;
      _isApplyingAiDraft = false;
    });
  }

  void _applyMergedSuggestion(
    ProductAiDraftMergedSuggestion merged,
    int? categoryId,
  ) {
    final name = merged.name?.trim();
    if ((name ?? '').isNotEmpty && _nameController.text.trim().isEmpty) {
      _nameController.text = name!;
    }
    final brand = merged.brand?.trim();
    if ((brand ?? '').isNotEmpty && _brandController.text.trim().isEmpty) {
      _brandController.text = brand!;
    }
    if (merged.priceHint != null && _priceController.text.trim().isEmpty) {
      _priceController.text = asNumberInput(merged.priceHint);
    }
    if (merged.nutrition != null && !_hasNutritionInput && !_nutritionSkipped) {
      _caloriesController.text = asNumberInput(merged.nutrition!.calories);
      _proteinController.text = asNumberInput(merged.nutrition!.proteinG);
      _carbsController.text = asNumberInput(merged.nutrition!.carbsG);
      _fatController.text = asNumberInput(merged.nutrition!.fatG);
    }
    if (categoryId != null && _categoryId == null) {
      _categoryId = categoryId;
    }
  }

  Future<void> _captureImage(ValueChanged<String> applyPath) async {
    final path = await _chooseImagePath();
    if (!mounted || path == null || path.trim().isEmpty) {
      return;
    }
    setState(() => applyPath(path));
  }

  Future<String?> _chooseImagePath() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (modalContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.of(modalContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () =>
                    Navigator.of(modalContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || source == null) {
      return null;
    }
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      return picked?.path;
    } catch (error) {
      if (!mounted) {
        return null;
      }
      setState(() {
        _serverMessage = formatErrorMessageForUi(
          error,
          debugModeEnabled: ref.read(debugModeEnabledProvider),
        );
      });
      return null;
    }
  }

  Future<void> _submit() async {
    if (!_reviewFormKey.currentState!.validate()) {
      return;
    }
    if (_categoryId == null || _supermarketId == null) {
      return;
    }
    final barcodeIsUnique = await _ensureBarcodeStillUnique();
    if (!barcodeIsUnique) {
      return;
    }

    setState(() {
      _serverMessage = null;
      _fieldErrors = const {};
    });

    String? imageUrl = _imageUrl;
    if ((_productImagePath ?? '').trim().isNotEmpty) {
      setState(() => _isUploadingImage = true);
      try {
        imageUrl = await ref
            .read(submissionRepositoryProvider)
            .uploadProductImage(_productImagePath!);
        if (!mounted) {
          return;
        }
        setState(() {
          _imageUrl = imageUrl;
          _productImagePath = null;
        });
      } catch (error) {
        if (!mounted) {
          return;
        }
        _applyError(error);
        return;
      } finally {
        if (mounted) {
          setState(() => _isUploadingImage = false);
        }
      }
    }

    final calories = parseOptionalDouble(_caloriesController.text);
    final proteinG = parseOptionalDouble(_proteinController.text);
    final carbsG = parseOptionalDouble(_carbsController.text);
    final fatG = parseOptionalDouble(_fatController.text);
    final hasNutrition =
        !_nutritionSkipped &&
        (calories != null ||
            proteinG != null ||
            carbsG != null ||
            fatG != null);

    final request = ProductSubmissionRequestDto(
      categoryId: _categoryId!,
      name: _nameController.text.trim(),
      brand: _brandController.text,
      barcode: normalizeBarcodeInput(_barcodeController.text),
      supermarketId: _supermarketId!,
      price: double.parse(_priceController.text.trim()),
      imageUrl: imageUrl,
      nutrition: hasNutrition
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
    _barcodeController.clear();
    _nameController.clear();
    _brandController.clear();
    _priceController.clear();
    _caloriesController.clear();
    _proteinController.clear();
    _carbsController.clear();
    _fatController.clear();
    setState(() {
      _stepIndex = 0;
      _categoryId = null;
      _supermarketId = null;
      _duplicateProduct = null;
      _priceImagePath = null;
      _nutritionImagePath = null;
      _productImagePath = null;
      _imageUrl = null;
      _nutritionSkipped = false;
      _barcodeReady = false;
      _verifiedBarcode = null;
      _serverMessage = null;
      _stepMessage = null;
      _categoryMessage = null;
      _fieldErrors = const {};
      _aiWarnings = const [];
      _aiFlags = const [];
    });
    ref.read(productSubmissionControllerProvider.notifier).clear();
  }

  Future<bool> _ensureBarcodeStillUnique() async {
    final normalized = normalizeBarcodeInput(_barcodeController.text);
    if (normalized.isEmpty) {
      return false;
    }
    if (_barcodeReady && _verifiedBarcode == normalized) {
      return true;
    }

    setState(() {
      _isCheckingBarcode = true;
      _serverMessage = null;
    });
    try {
      final results = await ref
          .read(catalogRepositoryProvider)
          .getProducts(query: normalized);
      if (!mounted) {
        return false;
      }
      final duplicate = findExactBarcodeMatch(
        scannedValue: normalized,
        searchResults: results,
      );
      setState(() {
        _isCheckingBarcode = false;
        _duplicateProduct = duplicate;
        _barcodeReady = duplicate == null;
        _verifiedBarcode = duplicate == null ? normalized : null;
        if (duplicate != null) {
          _stepIndex = 0;
          _stepMessage =
              'This barcode already exists. Submit a price update instead.';
        }
      });
      return duplicate == null;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _isCheckingBarcode = false;
        _serverMessage = formatErrorMessageForUi(
          error,
          debugModeEnabled: ref.read(debugModeEnabledProvider),
        );
      });
      return false;
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

class _ImageCaptureTile extends StatelessWidget {
  const _ImageCaptureTile({
    required this.label,
    required this.path,
    required this.enabled,
    required this.onCapture,
    required this.onRemove,
  });

  final String label;
  final String? path;
  final bool enabled;
  final VoidCallback onCapture;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final hasImage = (path ?? '').trim().isNotEmpty;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final disabledColor = colorScheme.onSurface.withValues(alpha: 0.38);
    final borderColor = enabled
        ? colorScheme.outline
        : colorScheme.onSurface.withValues(alpha: 0.22);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: enabled ? colorScheme.primary : disabledColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hasImage ? 'Photo selected' : 'No photo selected',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: enabled ? colorScheme.onSurface : disabledColor,
                  ),
                ),
              ),
              if (hasImage) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: enabled ? onRemove : null,
                  icon: const Icon(Icons.close),
                ),
              ],
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: enabled ? onCapture : null,
                child: Text(hasImage ? 'Change' : 'Capture'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _InlineMessageList extends StatelessWidget {
  const _InlineMessageList({
    required this.title,
    required this.items,
    required this.color,
  });

  final String title;
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '- $item',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
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
