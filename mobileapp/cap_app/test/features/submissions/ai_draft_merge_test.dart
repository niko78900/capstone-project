// File purpose: Covers Flutter tests for ai draft merge test behavior.
import 'package:cap_app/features/submissions/models/submission_models.dart';
import 'package:cap_app/features/submissions/utils/ai_draft_merge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('merges ai drafts without using AI barcode output', () {
    final merged = mergeAiDraftResponses(
      responsesByType: {
        AiCaptureType.price: const ProductAiDraftResponseDto(
          status: 'COMPLETED',
          name: 'Fallback Name',
          brand: 'Fallback Brand',
          barcode: '1000000000021',
          categoryHint: 'Beverages',
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

    expect(merged.barcode, isNull);
    expect(merged.priceHint, 29.0);
    expect(merged.supermarketHint, 'Tinex');
    expect(merged.nutrition?.calories, 200);
    expect(merged.name, 'Nutrition Name');
    expect(merged.brand, 'Fallback Brand');
    expect(merged.categoryHint, 'Beverages');
    expect(
      merged.warnings,
      containsAll(['price warning', 'nutrition warning']),
    );
    expect(merged.flags, containsAll(['price_flag', 'nutrition_flag']));
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
      skippedTypes: const {AiCaptureType.nutrition},
    );

    expect(merged.priceHint, 33.5);
    expect(merged.barcode, isNull);
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
