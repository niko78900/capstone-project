import 'package:cap_app/features/submissions/models/submission_models.dart';

ProductAiDraftMergedSuggestion mergeAiDraftResponses({
  required Map<AiCaptureType, ProductAiDraftResponseDto> responsesByType,
  Set<AiCaptureType> skippedTypes = const {},
}) {
  final nutritionDraft = responsesByType[AiCaptureType.nutrition];
  final priceDraft = responsesByType[AiCaptureType.price];

  final warnings = <String>{};
  final flags = <String>{};

  for (final type in const [AiCaptureType.price, AiCaptureType.nutrition]) {
    final response = responsesByType[type];
    if (response == null) {
      if (skippedTypes.contains(type)) {
        warnings.add(
          '${type.label} skipped. AI suggestions may be incomplete.',
        );
      }
      continue;
    }
    warnings.addAll(response.warnings.where((item) => item.trim().isNotEmpty));
    flags.addAll(response.flags.where((item) => item.trim().isNotEmpty));
    if (response.status != 'COMPLETED') {
      warnings.add(
        '${type.label} AI draft returned ${response.status}. Some suggestions may be missing.',
      );
    }
  }

  return ProductAiDraftMergedSuggestion(
    barcode: null,
    priceHint: _firstNonNull<double>([
      priceDraft?.priceHint,
      nutritionDraft?.priceHint,
    ]),
    supermarketHint: _firstNonBlank([
      priceDraft?.supermarketHint,
      nutritionDraft?.supermarketHint,
    ]),
    nutrition: nutritionDraft?.nutrition ?? priceDraft?.nutrition,
    name: _firstNonBlank([nutritionDraft?.name, priceDraft?.name]),
    brand: _firstNonBlank([nutritionDraft?.brand, priceDraft?.brand]),
    categoryHint: _firstNonBlank([
      nutritionDraft?.categoryHint,
      priceDraft?.categoryHint,
    ]),
    warnings: warnings.toList(),
    flags: flags.toList(),
  );
}

T? _firstNonNull<T>(List<T?> values) {
  for (final value in values) {
    if (value != null) {
      return value;
    }
  }
  return null;
}

String? _firstNonBlank(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}
