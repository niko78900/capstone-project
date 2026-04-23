import 'package:cap_app/core/errors/app_exception.dart';
import 'package:cap_app/core/errors/error_presenter.dart';
import 'package:cap_app/features/catalog/models/catalog_models.dart';
import 'package:cap_app/features/catalog/providers/catalog_providers.dart';
import 'package:cap_app/features/settings/providers/settings_providers.dart';
import 'package:cap_app/features/submissions/models/submission_models.dart';
import 'package:cap_app/features/submissions/providers/submission_providers.dart';
import 'package:cap_app/shared/widgets/android_back_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SubmitPriceScreen extends ConsumerStatefulWidget {
  const SubmitPriceScreen({this.initialProductId, super.key});

  final int? initialProductId;

  @override
  ConsumerState<SubmitPriceScreen> createState() => _SubmitPriceScreenState();
}

class _SubmitPriceScreenState extends ConsumerState<SubmitPriceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();

  int? _productId;
  int? _supermarketId;
  DateTime? _observedAt;
  String? _serverMessage;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    _productId = widget.initialProductId;
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(allProductsProvider);
    final supermarketsAsync = ref.watch(supermarketsProvider);
    final submitState = ref.watch(priceSubmissionControllerProvider);
    final isSubmitting = submitState.isLoading;
    final debugModeEnabled = ref.watch(debugModeEnabledProvider);

    return BackToHomeScope(
      child: Scaffold(
        appBar: AppBar(title: const Text('Submit Price')),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allProductsProvider);
              ref.invalidate(supermarketsProvider);
              await Future.wait([
                ref.read(allProductsProvider.future),
                ref.read(supermarketsProvider.future),
              ]);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                productsAsync.when(
                  data: (products) => _ProductPickerField(
                    products: products,
                    value: _productId,
                    errorText: _fieldErrors['productId'],
                    enabled: !isSubmitting,
                    onTap: () => _pickProduct(products),
                  ),
                  loading: () =>
                      const _LoadingField(label: 'Loading products...'),
                  error: (error, _) => _ErrorField(
                    message: formatErrorMessageForUi(
                      error,
                      debugModeEnabled: debugModeEnabled,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                supermarketsAsync.when(
                  data: (supermarkets) => _SupermarketDropdown(
                    supermarkets: supermarkets,
                    value: _supermarketId,
                    errorText: _fieldErrors['supermarketId'],
                    enabled: !isSubmitting,
                    onChanged: (value) =>
                        setState(() => _supermarketId = value),
                  ),
                  loading: () =>
                      const _LoadingField(label: 'Loading supermarkets...'),
                  error: (error, _) => _ErrorField(
                    message: formatErrorMessageForUi(
                      error,
                      debugModeEnabled: debugModeEnabled,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
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
                      InkWell(
                        onTap: isSubmitting ? null : _pickObservedAt,
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Observed at time',
                            hintText: 'Tap to select date and time',
                            errorText: _fieldErrors['observedAt'],
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_observedAt != null)
                                  IconButton(
                                    tooltip: 'Clear date and time',
                                    onPressed: isSubmitting
                                        ? null
                                        : _clearObservedAt,
                                    icon: const Icon(Icons.close),
                                  ),
                                IconButton(
                                  tooltip: 'Select date and time',
                                  onPressed: isSubmitting
                                      ? null
                                      : _pickObservedAt,
                                  icon: const Icon(Icons.event),
                                ),
                              ],
                            ),
                          ),
                          child: Text(
                            _observedAt == null
                                ? 'Tap to choose date and time'
                                : _formatObservedAt(_observedAt!),
                          ),
                        ),
                      ),
                    ],
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
                  onPressed: isSubmitting ? null : _submit,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit price update'),
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
    if (_productId == null || _supermarketId == null) {
      setState(() {
        _fieldErrors = {
          ..._fieldErrors,
          if (_productId == null) 'productId': 'Product is required',
          if (_supermarketId == null)
            'supermarketId': 'Supermarket is required',
        };
      });
      return;
    }

    setState(() {
      _serverMessage = null;
      _fieldErrors = const {};
    });

    final request = PriceSubmissionRequestDto(
      productId: _productId!,
      supermarketId: _supermarketId!,
      price: double.parse(_priceController.text.trim()),
      observedAt: _observedAt,
    );

    final result = await ref
        .read(priceSubmissionControllerProvider.notifier)
        .submit(request);
    if (result == null) {
      final error = ref.read(priceSubmissionControllerProvider).asError?.error;
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
        content: Text('Price submission created and pending moderation.'),
      ),
    );
    _clearForm();
  }

  void _clearForm() {
    _priceController.clear();
    setState(() {
      _productId = null;
      _supermarketId = null;
      _observedAt = null;
      _serverMessage = null;
      _fieldErrors = const {};
    });
    ref.read(priceSubmissionControllerProvider.notifier).clear();
  }

  Future<void> _pickObservedAt() async {
    final now = DateTime.now();
    final initial = _observedAt ?? now;
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (selectedDate == null || !mounted) {
      return;
    }

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (selectedTime == null) {
      return;
    }

    final picked = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    final nextFieldErrors = Map<String, String>.from(_fieldErrors);
    nextFieldErrors.remove('observedAt');
    setState(() {
      _observedAt = picked;
      _fieldErrors = nextFieldErrors;
    });
  }

  void _clearObservedAt() {
    final nextFieldErrors = Map<String, String>.from(_fieldErrors);
    nextFieldErrors.remove('observedAt');
    setState(() {
      _observedAt = null;
      _fieldErrors = nextFieldErrors;
    });
  }

  String _formatObservedAt(DateTime value) {
    final local = value.toLocal();
    final localization = MaterialLocalizations.of(context);
    final date = localization.formatMediumDate(local);
    final time = localization.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );
    return '$date - $time';
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

  Future<void> _pickProduct(List<ProductSummaryDto> products) async {
    final selectedProductId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (modalContext) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredProducts = _filterProducts(products, query);
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: MediaQuery.of(modalContext).viewInsets.bottom + 16,
                ),
                child: SizedBox(
                  height: 480,
                  child: Column(
                    children: [
                      TextField(
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Search products',
                          hintText: 'Type product name, brand, or category',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            query = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filteredProducts.isEmpty
                            ? const Center(
                                child: Text(
                                  'No products found for your search.',
                                ),
                              )
                            : ListView.separated(
                                itemCount: filteredProducts.length,
                                separatorBuilder: (_, index) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final product = filteredProducts[index];
                                  return ListTile(
                                    title: Text(product.name),
                                    subtitle: Text(
                                      '${product.brand ?? 'Unbranded'} - ${product.category}',
                                    ),
                                    onTap: () =>
                                        Navigator.of(context).pop(product.id),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || selectedProductId == null) {
      return;
    }

    final nextFieldErrors = Map<String, String>.from(_fieldErrors);
    nextFieldErrors.remove('productId');
    setState(() {
      _productId = selectedProductId;
      _fieldErrors = nextFieldErrors;
    });
  }

  List<ProductSummaryDto> _filterProducts(
    List<ProductSummaryDto> products,
    String query,
  ) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return products;
    }
    return products.where((product) {
      final name = product.name.toLowerCase();
      final brand = product.brand?.toLowerCase() ?? '';
      final category = product.category.toLowerCase();
      return name.contains(normalizedQuery) ||
          brand.contains(normalizedQuery) ||
          category.contains(normalizedQuery);
    }).toList();
  }
}

class _ProductPickerField extends StatelessWidget {
  const _ProductPickerField({
    required this.products,
    required this.value,
    required this.onTap,
    required this.enabled,
    this.errorText,
  });

  final List<ProductSummaryDto> products;
  final int? value;
  final VoidCallback onTap;
  final bool enabled;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    ProductSummaryDto? selectedProduct;
    for (final product in products) {
      if (product.id == value) {
        selectedProduct = product;
        break;
      }
    }

    final displayText = selectedProduct == null
        ? 'Tap to choose a product'
        : '${selectedProduct.name} (${selectedProduct.brand ?? 'Unbranded'})';

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Product',
          errorText: errorText,
          suffixIcon: const Icon(Icons.search),
          enabled: enabled,
        ),
        child: Text(displayText),
      ),
    );
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
