import 'package:cap_app/features/submissions/models/submission_models.dart';
import 'package:cap_app/features/submissions/utils/ai_draft_merge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('merges ai drafts with deterministic capture-type precedence', () {
    final merged = mergeAiDraftResponses(
      responsesByType: {
        AiCaptureType.barcode: const ProductAiDraftResponseDto(
          status: 'COMPLETED',
          name: 'Cola 2L',
          brand: 'Coca-Cola',
          barcode: '1000000000021',
          categoryHint: 'Beverages',
          warnings: ['barcode warning'],
          flags: ['barcode_flag'],
        ),
        AiCaptureType.price: const ProductAiDraftResponseDto(
          status: 'COMPLETED',
          name: 'Fallback Name',
          supermarketHint: 'Tinex',
          priceHint: 29.0,
          warnings: ['price warning'],
          flags: ['price_flag'],
        ),
        AiCaptureType.nutrition: const ProductAiDraftResponseDto(
          status: 'COMPLETED',
          name: 'Nutrition Name',
          nutrition: SubmissionNutritionInput(
            calories: 200,
            proteinG: 2,
            carbsG: 18,
            fatG: 1,
            servingSize: '100 g',
          ),
          warnings: ['nutrition warning'],
          flags: ['nutrition_flag'],
        ),
      },
    );

    expect(merged.barcode, '1000000000021');
    expect(merged.priceHint, 29.0);
    expect(merged.supermarketHint, 'Tinex');
    expect(merged.nutrition?.calories, 200);
    expect(merged.name, 'Cola 2L');
    expect(merged.brand, 'Coca-Cola');
    expect(merged.categoryHint, 'Beverages');
    expect(
      merged.warnings,
      containsAll(['barcode warning', 'price warning', 'nutrition warning']),
    );
    expect(
      merged.flags,
      containsAll(['barcode_flag', 'price_flag', 'nutrition_flag']),
    );
  });

  test('keeps usable output for partial or non-completed slot responses', () {
    final merged = mergeAiDraftResponses(
      responsesByType: {
        AiCaptureType.price: const ProductAiDraftResponseDto(
          status: 'FAILED',
          priceHint: 33.5,
          warnings: ['could not parse shelf row'],
        ),
      },
      skippedTypes: const {AiCaptureType.barcode, AiCaptureType.nutrition},
    );

    expect(merged.priceHint, 33.5);
    expect(merged.barcode, isNull);
    expect(
      merged.warnings.any((item) => item.contains('Barcode photo skipped')),
      isTrue,
    );
    expect(
      merged.warnings.any((item) => item.contains('Nutrition photo skipped')),
      isTrue,
    );
    expect(
      merged.warnings.any((item) => item.contains('returned FAILED')),
      isTrue,
    );
  });
}
