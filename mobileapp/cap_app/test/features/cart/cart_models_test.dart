import 'package:cap_app/features/cart/models/cart_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CartComparisonResponse', () {
    test('maps full coverage response', () {
      final response = CartComparisonResponse.fromJson({
        'requestItemCount': 2,
        'cheapestEligible': {
          'supermarketId': 1,
          'supermarketName': 'Tinex',
          'totalCost': 199.5,
          'currency': 'MKD',
        },
        'rankedSupermarkets': [
          {
            'supermarketId': 1,
            'supermarketName': 'Tinex',
            'totalCost': 199.5,
            'currency': 'MKD',
            'fullCoverage': true,
            'coverageRatio': 1.0,
            'missingItems': [],
            'lineItems': [
              {
                'productId': 10,
                'productName': 'Milk',
                'quantity': 2,
                'unitPrice': 65.5,
                'lineTotal': 131.0,
              },
            ],
          },
        ],
        'diagnostics': {
          'eligibleSupermarkets': 1,
          'partialSupermarkets': 0,
          'totalSupermarkets': 5,
        },
      });

      expect(response.requestItemCount, 2);
      expect(response.cheapestEligible, isNotNull);
      expect(response.cheapestEligible?.supermarketName, 'Tinex');
      expect(response.rankedSupermarkets.first.fullCoverage, isTrue);
      expect(response.diagnostics.eligibleSupermarkets, 1);
    });

    test('maps partial coverage response with missing items', () {
      final response = CartComparisonResponse.fromJson({
        'requestItemCount': 3,
        'cheapestEligible': null,
        'rankedSupermarkets': [
          {
            'supermarketId': 5,
            'supermarketName': 'Stokomak',
            'totalCost': 150,
            'currency': 'MKD',
            'fullCoverage': false,
            'coverageRatio': 0.67,
            'missingItems': [
              {
                'productId': 7,
                'productName': 'Frozen Pizza',
              },
            ],
            'lineItems': [],
          },
        ],
        'diagnostics': {
          'eligibleSupermarkets': 0,
          'partialSupermarkets': 1,
          'totalSupermarkets': 5,
        },
      });

      expect(response.cheapestEligible, isNull);
      expect(response.rankedSupermarkets.first.fullCoverage, isFalse);
      expect(response.rankedSupermarkets.first.missingItems, hasLength(1));
      expect(response.rankedSupermarkets.first.missingItems.first.productName, 'Frozen Pizza');
      expect(response.diagnostics.partialSupermarkets, 1);
    });
  });
}
