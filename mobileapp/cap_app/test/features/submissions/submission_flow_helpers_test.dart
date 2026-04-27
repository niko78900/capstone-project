import 'package:cap_app/features/catalog/models/catalog_models.dart';
import 'package:cap_app/features/submissions/models/submission_models.dart';
import 'package:cap_app/features/submissions/utils/submission_flow_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('findExactBarcodeMatch', () {
    test('matches only normalized exact barcodes', () {
      final match = findExactBarcodeMatch(
        scannedValue: ' 123 456 ',
        searchResults: const [
          ProductSummaryDto(
            id: 1,
            name: 'Similar',
            barcode: '123',
            category: 'Snacks',
          ),
          ProductSummaryDto(
            id: 2,
            name: 'Exact',
            barcode: '123456',
            category: 'Snacks',
          ),
        ],
      );

      expect(match?.id, 2);
    });
  });

  group('resolveCategoryHint', () {
    test('maps category hints only to existing categories', () {
      final resolution = resolveCategoryHint(categoryHint: 'Beverages');

      expect(resolution.categoryId, 8);
      expect(resolution.requiresManualSelection, isFalse);
    });

    test('requires manual category selection for unknown hints', () {
      final resolution = resolveCategoryHint(categoryHint: 'Imported sauces');

      expect(resolution.categoryId, isNull);
      expect(resolution.requiresManualSelection, isTrue);
    });

    test('requires manual category selection for low confidence hints', () {
      final resolution = resolveCategoryHint(
        categoryHint: 'Beverages',
        drafts: const [
          ProductAiDraftResponseDto(
            status: 'COMPLETED',
            categoryHint: 'Beverages',
            confidence: 0.4,
          ),
        ],
      );

      expect(resolution.categoryId, isNull);
      expect(resolution.requiresManualSelection, isTrue);
    });
  });
}
