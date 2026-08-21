// File purpose: Provides reusable Flutter helpers for catalog feature workflows.
import 'package:cap_app/features/catalog/models/catalog_models.dart';

enum BarcodeResolutionType { openProductDetail, openSubmitProduct }

class BarcodeResolutionResult {
  const BarcodeResolutionResult._({
    required this.type,
    this.productId,
    this.barcode,
  });

  final BarcodeResolutionType type;
  final int? productId;
  final String? barcode;

  factory BarcodeResolutionResult.openProductDetail(int productId) {
    return BarcodeResolutionResult._(
      type: BarcodeResolutionType.openProductDetail,
      productId: productId,
    );
  }

  factory BarcodeResolutionResult.openSubmitProduct(String barcode) {
    return BarcodeResolutionResult._(
      type: BarcodeResolutionType.openSubmitProduct,
      barcode: barcode,
    );
  }
}

String normalizeBarcodeInput(String value) {
  return value.replaceAll(RegExp(r'\s+'), '').trim();
}

BarcodeResolutionResult resolveBarcodeResult({
  required String scannedValue,
  required List<ProductSummaryDto> searchResults,
}) {
  final normalizedScan = normalizeBarcodeInput(scannedValue);
  for (final product in searchResults) {
    final normalizedProductBarcode = normalizeBarcodeInput(
      product.barcode ?? '',
    );
    if (normalizedProductBarcode.isEmpty) {
      continue;
    }
    if (normalizedProductBarcode == normalizedScan) {
      return BarcodeResolutionResult.openProductDetail(product.id);
    }
  }
  return BarcodeResolutionResult.openSubmitProduct(normalizedScan);
}
