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
import 'package:cap_app/features/submissions/utils/submission_flow_helpers.dart';
import 'package:cap_app/shared/widgets/android_back_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _PriceUpdateStage { scan, confirm, submit, notFound }

class SubmitPriceScreen extends ConsumerStatefulWidget {
  const SubmitPriceScreen({this.initialProductId, super.key});

  final int? initialProductId;

  @override
  ConsumerState<SubmitPriceScreen> createState() => _SubmitPriceScreenState();
}

class _SubmitPriceScreenState extends ConsumerState<SubmitPriceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _barcodeController = TextEditingController();
  final _priceController = TextEditingController();

  _PriceUpdateStage _stage = _PriceUpdateStage.scan;
  ProductSummaryDto? _matchedProduct;
  int? _productId;
  int? _supermarketId;
  String? _scannedBarcode;
  String? _serverMessage;
  Map<String, String> _fieldErrors = const {};
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    final initialProductId = widget.initialProductId;
    if (initialProductId != null) {
      _productId = initialProductId;
      _stage = _PriceUpdateStage.submit;
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(priceSubmissionControllerProvider);
    final isSubmitting = submitState.isLoading;
    final isBusy = isSubmitting || _isSearching;

    return BackToHomeScope(
      child: Scaffold(
        appBar: AppBar(title: const Text('Submit Price Update')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_stage == _PriceUpdateStage.scan) _buildScanStage(isBusy),
              if (_stage == _PriceUpdateStage.confirm)
                _buildConfirmStage(isBusy),
              if (_stage == _PriceUpdateStage.notFound)
                _buildNotFoundStage(isBusy),
              if (_stage == _PriceUpdateStage.submit) _buildSubmitStage(isBusy),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanStage(bool isBusy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Scan the product barcode to find it in the catalog.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _barcodeController,
          enabled: !isBusy,
          decoration: const InputDecoration(
            labelText: 'Barcode',
            helperText:
                'Scan first, or enter the code if scanning is unavailable.',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: isBusy ? null : _scanBarcode,
          icon: const Icon(Icons.qr_code_scanner_outlined),
          label: const Text('Scan barcode'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: isBusy ? null : _searchTypedBarcode,
          icon: _isSearching
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search_outlined),
          label: const Text('Search barcode'),
        ),
        if (_serverMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _serverMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildConfirmStage(bool isBusy) {
    final product = _matchedProduct;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Confirm the matched product.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (product != null) _ProductSummaryCard(product: product),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: isBusy
              ? null
              : () {
                  setState(() {
                    _productId = product?.id;
                    _stage = _PriceUpdateStage.submit;
                    _serverMessage = null;
                  });
                },
          icon: const Icon(Icons.check_outlined),
          label: const Text('This is the product'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: isBusy ? null : _scanAgain,
          icon: const Icon(Icons.qr_code_scanner_outlined),
          label: const Text('Scan again'),
        ),
      ],
    );
  }

  Widget _buildNotFoundStage(bool isBusy) {
    final barcode =
        _scannedBarcode ?? normalizeBarcodeInput(_barcodeController.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Product not found',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'No catalog product matched barcode $barcode. Add the product first or scan again.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: isBusy
              ? null
              : () => context.push(
                  AppRoutes.submitProductGuided,
                  extra: {'prefillBarcode': barcode},
                ),
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Submit product guided'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: isBusy
              ? null
              : () => context.push(
                  AppRoutes.submitProduct,
                  extra: {'prefillBarcode': barcode},
                ),
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Submit product manually'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: isBusy ? null : _scanAgain,
          icon: const Icon(Icons.qr_code_scanner_outlined),
          label: const Text('Scan again'),
        ),
      ],
    );
  }

  Widget _buildSubmitStage(bool isBusy) {
    final productId = _productId;
    if (productId == null) {
      return _buildScanStage(isBusy);
    }

    final product = _matchedProduct;
    final detailAsync = widget.initialProductId == productId && product == null
        ? ref.watch(productDetailProvider(productId))
        : null;
    final supermarketsAsync = ref.watch(supermarketsProvider);
    final debugModeEnabled = ref.watch(debugModeEnabledProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (detailAsync != null)
          detailAsync.when(
            data: (detail) => _ProductDetailCard(detail: detail),
            loading: () => const _LoadingField(label: 'Loading product...'),
            error: (error, _) => _ErrorField(
              message: formatErrorMessageForUi(
                error,
                debugModeEnabled: debugModeEnabled,
              ),
            ),
          )
        else if (product != null)
          _ProductSummaryCard(product: product)
        else
          _UnknownProductCard(productId: productId),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            children: [
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
                  validator: (value) =>
                      value == null ? 'Market is required' : null,
                ),
                loading: () => const _LoadingField(label: 'Loading markets...'),
                error: (error, _) => _ErrorField(
                  message: formatErrorMessageForUi(
                    error,
                    debugModeEnabled: debugModeEnabled,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                enabled: !isBusy,
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
            ],
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
          onPressed: isBusy ? null : _submit,
          child: isBusy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit price update'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: isBusy ? null : _scanAgain,
          icon: const Icon(Icons.qr_code_scanner_outlined),
          label: const Text('Scan a different barcode'),
        ),
      ],
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
    _barcodeController.text = normalized;
    await _lookupBarcode(normalized);
  }

  Future<void> _searchTypedBarcode() async {
    final normalized = normalizeBarcodeInput(_barcodeController.text);
    if (normalized.isEmpty) {
      setState(() => _serverMessage = 'Enter or scan a barcode first.');
      return;
    }
    await _lookupBarcode(normalized);
  }

  Future<void> _lookupBarcode(String barcode) async {
    setState(() {
      _isSearching = true;
      _serverMessage = null;
      _fieldErrors = const {};
      _matchedProduct = null;
      _productId = null;
      _scannedBarcode = barcode;
    });

    try {
      final results = await ref
          .read(catalogRepositoryProvider)
          .getProducts(query: barcode);
      if (!mounted) {
        return;
      }
      final match = findExactBarcodeMatch(
        scannedValue: barcode,
        searchResults: results,
      );
      setState(() {
        _isSearching = false;
        _matchedProduct = match;
        _productId = match?.id;
        _stage = match == null
            ? _PriceUpdateStage.notFound
            : _PriceUpdateStage.confirm;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSearching = false;
        _serverMessage = formatErrorMessageForUi(
          error,
          debugModeEnabled: ref.read(debugModeEnabledProvider),
        );
      });
    }
  }

  void _scanAgain() {
    _barcodeController.clear();
    _priceController.clear();
    setState(() {
      _stage = _PriceUpdateStage.scan;
      _matchedProduct = null;
      _productId = null;
      _supermarketId = null;
      _scannedBarcode = null;
      _serverMessage = null;
      _fieldErrors = const {};
    });
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
          if (_supermarketId == null) 'supermarketId': 'Market is required',
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
    _clearSubmissionFields();
  }

  void _clearSubmissionFields() {
    _priceController.clear();
    setState(() {
      _supermarketId = null;
      _serverMessage = null;
      _fieldErrors = const {};
    });
    ref.read(priceSubmissionControllerProvider.notifier).clear();
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

class _ProductSummaryCard extends StatelessWidget {
  const _ProductSummaryCard({required this.product});

  final ProductSummaryDto product;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(product.brand ?? 'Unbranded'),
            Text('Category: ${product.category}'),
            if ((product.barcode ?? '').trim().isNotEmpty)
              Text('Barcode: ${product.barcode}'),
          ],
        ),
      ),
    );
  }
}

class _ProductDetailCard extends StatelessWidget {
  const _ProductDetailCard({required this.detail});

  final ProductDetailDto detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(detail.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(detail.brand ?? 'Unbranded'),
            Text('Category: ${detail.category}'),
            if ((detail.barcode ?? '').trim().isNotEmpty)
              Text('Barcode: ${detail.barcode}'),
          ],
        ),
      ),
    );
  }
}

class _UnknownProductCard extends StatelessWidget {
  const _UnknownProductCard({required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Product #$productId'),
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
