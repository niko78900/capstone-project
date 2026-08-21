// File purpose: Covers Flutter tests for catalog models test behavior.
import 'package:cap_app/features/catalog/models/catalog_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'ProductDetailDto parses price history and defaults missing history',
    () {
      final detail = ProductDetailDto.fromJson({
        'id': 1,
        'name': 'Milk',
        'brand': 'Bucen Kozjak',
        'barcode': '123',
        'imageUrl': null,
        'category': 'Dairy',
        'nutrition': null,
        'prices': const [],
        'priceHistory': [
          {
            'supermarketId': 1,
            'supermarketName': 'Tinex',
            'price': 62.5,
            'currency': 'MKD',
            'observedAt': '2026-04-10T10:00:00Z',
          },
        ],
        'unavailableMarkets': [
          {
            'supermarketId': 2,
            'supermarketName': 'Vero',
            'available': false,
            'observedAt': '2026-05-10T10:00:00Z',
          },
        ],
      });

      expect(detail.priceHistory, hasLength(1));
      expect(detail.priceHistory.first.supermarketName, 'Tinex');
      expect(detail.priceHistory.first.price, 62.5);
      expect(detail.unavailableMarkets, hasLength(1));
      expect(detail.unavailableMarkets.first.supermarketName, 'Vero');

      final legacyDetail = ProductDetailDto.fromJson({
        'id': 2,
        'name': 'Bread',
        'category': 'Bakery',
        'prices': const [],
      });
      expect(legacyDetail.priceHistory, isEmpty);
      expect(legacyDetail.unavailableMarkets, isEmpty);
    },
  );
}
