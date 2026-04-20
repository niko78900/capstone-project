import 'package:cap_app/features/catalog/models/catalog_models.dart';
import 'package:cap_app/features/catalog/utils/barcode_resolution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns product detail action for exact barcode match', () {
    final results = [
      const ProductSummaryDto(
        id: 22,
        name: 'Cola 2L',
        barcode: '1000000000021',
        category: 'Beverages',
      ),
    ];

    final action = resolveBarcodeResult(
      scannedValue: ' 1000000000021 ',
      searchResults: results,
    );

    expect(action.type, BarcodeResolutionType.openProductDetail);
    expect(action.productId, 22);
    expect(action.barcode, isNull);
  });

  test('returns submit action when there is no exact barcode match', () {
    final results = [
      const ProductSummaryDto(
        id: 1,
        name: 'Apple Gala',
        barcode: '1000000000011',
        category: 'Fruits & Vegetables',
      ),
    ];

    final action = resolveBarcodeResult(
      scannedValue: '9999999999999',
      searchResults: results,
    );

    expect(action.type, BarcodeResolutionType.openSubmitProduct);
    expect(action.barcode, '9999999999999');
    expect(action.productId, isNull);
  });
}
