// File purpose: Provides reusable Flutter helpers for submissions feature workflows.
import 'package:cap_app/features/catalog/models/catalog_models.dart';
import 'package:cap_app/features/catalog/utils/barcode_resolution.dart';
import 'package:cap_app/features/submissions/models/submission_models.dart';

const double defaultAiCategoryConfidenceThreshold = 0.65;

class CategoryHintResolution {
  const CategoryHintResolution({
    required this.categoryId,
    required this.requiresManualSelection,
    required this.message,
  });

  final int? categoryId;
  final bool requiresManualSelection;
  final String message;
}

ProductSummaryDto? findExactBarcodeMatch({
  required String scannedValue,
  required List<ProductSummaryDto> searchResults,
}) {
  final normalizedScan = normalizeBarcodeInput(scannedValue);
  if (normalizedScan.isEmpty) {
    return null;
  }
  for (final product in searchResults) {
    final normalizedProductBarcode = normalizeBarcodeInput(
      product.barcode ?? '',
    );
    if (normalizedProductBarcode == normalizedScan) {
      return product;
    }
  }
  return null;
}

int? resolveCategoryIdFromHint(String? categoryHint) {
  final normalizedHint = (categoryHint ?? '').trim().toLowerCase();
  if (normalizedHint.isEmpty) {
    return null;
  }
  for (final option in categoryOptions) {
    final candidate = option.name.toLowerCase();
    if (candidate == normalizedHint ||
        candidate.contains(normalizedHint) ||
        normalizedHint.contains(candidate)) {
      return option.id;
    }
  }
  return null;
}

int resolveCategoryIdByName(String categoryName) {
  final normalized = categoryName.trim().toLowerCase();
  for (final option in categoryOptions) {
    if (option.name.toLowerCase() == normalized) {
      return option.id;
    }
  }
  return categoryOptions.first.id;
}

CategoryHintResolution resolveCategoryHint({
  required String? categoryHint,
  Iterable<ProductAiDraftResponseDto> drafts = const [],
  double confidenceThreshold = defaultAiCategoryConfidenceThreshold,
}) {
  final normalizedHint = (categoryHint ?? '').trim().toLowerCase();
  if (normalizedHint.isEmpty) {
    return const CategoryHintResolution(
      categoryId: null,
      requiresManualSelection: true,
      message: 'Select a category manually.',
    );
  }

  final hasLowConfidence = drafts.any((draft) {
    final confidence = draft.confidence;
    final hint = (draft.categoryHint ?? '').trim();
    return hint.isNotEmpty &&
        confidence != null &&
        confidence < confidenceThreshold;
  });
  if (hasLowConfidence) {
    return const CategoryHintResolution(
      categoryId: null,
      requiresManualSelection: true,
      message: 'AI confidence was low. Select a category manually.',
    );
  }

  final categoryId = resolveCategoryIdFromHint(categoryHint);
  if (categoryId != null) {
    final option = categoryOptions.firstWhere(
      (option) => option.id == categoryId,
    );
    return CategoryHintResolution(
      categoryId: categoryId,
      requiresManualSelection: false,
      message: 'AI suggested ${option.name}. Review before submitting.',
    );
  }

  return const CategoryHintResolution(
    categoryId: null,
    requiresManualSelection: true,
    message: 'AI category did not match the app list. Select one manually.',
  );
}

String asNumberInput(double? value) {
  if (value == null) {
    return '';
  }
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}

double? parseOptionalDouble(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return double.tryParse(trimmed);
}
