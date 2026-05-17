class CategoryOption {
  const CategoryOption({required this.id, required this.name});

  final int id;
  final String name;
}

const categoryOptions = <CategoryOption>[
  CategoryOption(id: 1, name: 'Fruits & Vegetables'),
  CategoryOption(id: 2, name: 'Bakery'),
  CategoryOption(id: 3, name: 'Dairy & Eggs'),
  CategoryOption(id: 4, name: 'Meat & Fish'),
  CategoryOption(id: 5, name: 'Pasta & Rice'),
  CategoryOption(id: 6, name: 'Canned & Jarred'),
  CategoryOption(id: 7, name: 'Snacks'),
  CategoryOption(id: 8, name: 'Beverages'),
  CategoryOption(id: 9, name: 'Frozen'),
  CategoryOption(id: 10, name: 'Household'),
];

enum SubmissionType { product, price, nutrition, availability, unknown }

enum SubmissionStatus { pending, approved, rejected, unknown }

SubmissionType parseSubmissionType(String? raw) {
  switch ((raw ?? '').toUpperCase()) {
    case 'PRODUCT':
      return SubmissionType.product;
    case 'PRICE':
      return SubmissionType.price;
    case 'NUTRITION':
      return SubmissionType.nutrition;
    case 'AVAILABILITY':
      return SubmissionType.availability;
    default:
      return SubmissionType.unknown;
  }
}

SubmissionStatus parseSubmissionStatus(String? raw) {
  switch ((raw ?? '').toUpperCase()) {
    case 'PENDING':
      return SubmissionStatus.pending;
    case 'APPROVED':
      return SubmissionStatus.approved;
    case 'REJECTED':
      return SubmissionStatus.rejected;
    default:
      return SubmissionStatus.unknown;
  }
}

class SubmissionNutritionInput {
  const SubmissionNutritionInput({
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.servingSize,
  });

  final double? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final String? servingSize;

  bool get isEmpty =>
      calories == null &&
      proteinG == null &&
      carbsG == null &&
      fatG == null &&
      (servingSize == null || servingSize!.trim().isEmpty);

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'proteinG': proteinG,
      'carbsG': carbsG,
      'fatG': fatG,
      'servingSize': servingSize,
    };
  }
}

enum AiCaptureType { price, nutrition }

extension AiCaptureTypeX on AiCaptureType {
  String get apiValue {
    switch (this) {
      case AiCaptureType.price:
        return 'PRICE';
      case AiCaptureType.nutrition:
        return 'NUTRITION';
    }
  }

  String get label {
    switch (this) {
      case AiCaptureType.price:
        return 'Price photo';
      case AiCaptureType.nutrition:
        return 'Nutrition photo';
    }
  }
}

class ProductAiDraftResponseDto {
  const ProductAiDraftResponseDto({
    required this.status,
    this.model,
    this.name,
    this.brand,
    this.barcode,
    this.categoryHint,
    this.supermarketHint,
    this.priceHint,
    this.nutrition,
    this.confidence,
    this.warnings = const [],
    this.flags = const [],
  });

  final String status;
  final String? model;
  final String? name;
  final String? brand;
  final String? barcode;
  final String? categoryHint;
  final String? supermarketHint;
  final double? priceHint;
  final SubmissionNutritionInput? nutrition;
  final double? confidence;
  final List<String> warnings;
  final List<String> flags;

  factory ProductAiDraftResponseDto.fromJson(Map<String, dynamic> json) {
    final nutritionRaw = json['nutrition'];
    final warningsRaw = json['warnings'];
    final flagsRaw = json['flags'];
    return ProductAiDraftResponseDto(
      status: _toString(json['status']).toUpperCase(),
      model: _nullIfBlank(json['model']?.toString()),
      name: _nullIfBlank(json['name']?.toString()),
      brand: _nullIfBlank(json['brand']?.toString()),
      barcode: _nullIfBlank(json['barcode']?.toString()),
      categoryHint: _nullIfBlank(json['categoryHint']?.toString()),
      supermarketHint: _nullIfBlank(json['supermarketHint']?.toString()),
      priceHint: _toDouble(json['priceHint']),
      nutrition: nutritionRaw is Map
          ? SubmissionNutritionInput(
              calories: _toDouble(nutritionRaw['calories']),
              proteinG: _toDouble(nutritionRaw['proteinG']),
              carbsG: _toDouble(nutritionRaw['carbsG']),
              fatG: _toDouble(nutritionRaw['fatG']),
              servingSize: _nullIfBlank(
                nutritionRaw['servingSize']?.toString(),
              ),
            )
          : null,
      confidence: _toDouble(json['confidence']),
      warnings: warningsRaw is List
          ? warningsRaw
                .map((item) => _nullIfBlank(item?.toString()))
                .whereType<String>()
                .toList()
          : const [],
      flags: flagsRaw is List
          ? flagsRaw
                .map((item) => _nullIfBlank(item?.toString()))
                .whereType<String>()
                .toList()
          : const [],
    );
  }
}

class ProductAiDraftMergedSuggestion {
  const ProductAiDraftMergedSuggestion({
    this.name,
    this.brand,
    this.barcode,
    this.categoryHint,
    this.supermarketHint,
    this.priceHint,
    this.nutrition,
    this.warnings = const [],
    this.flags = const [],
  });

  final String? name;
  final String? brand;
  final String? barcode;
  final String? categoryHint;
  final String? supermarketHint;
  final double? priceHint;
  final SubmissionNutritionInput? nutrition;
  final List<String> warnings;
  final List<String> flags;
}

class ProductSubmissionRequestDto {
  const ProductSubmissionRequestDto({
    required this.categoryId,
    this.sourceProductId,
    required this.name,
    this.brand,
    required this.barcode,
    required this.supermarketId,
    required this.price,
    this.imageUrl,
    this.nutrition,
    this.notes,
  });

  final int categoryId;
  final int? sourceProductId;
  final String name;
  final String? brand;
  final String barcode;
  final int supermarketId;
  final double price;
  final String? imageUrl;
  final SubmissionNutritionInput? nutrition;
  final String? notes;

  Map<String, dynamic> toJson() {
    return {
      'categoryId': categoryId,
      'sourceProductId': sourceProductId,
      'name': name,
      'brand': _nullIfBlank(brand),
      'barcode': _nullIfBlank(barcode),
      'supermarketId': supermarketId,
      'price': price,
      'imageUrl': _nullIfBlank(imageUrl),
      'nutrition': nutrition == null || nutrition!.isEmpty
          ? null
          : nutrition!.toJson(),
      'notes': _nullIfBlank(notes),
    };
  }
}

class PriceSubmissionRequestDto {
  const PriceSubmissionRequestDto({
    required this.productId,
    required this.supermarketId,
    this.branchId,
    required this.price,
    this.observedAt,
    this.imageUrl,
    this.notes,
  });

  final int productId;
  final int supermarketId;
  final int? branchId;
  final double price;
  final DateTime? observedAt;
  final String? imageUrl;
  final String? notes;

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'supermarketId': supermarketId,
      'branchId': branchId,
      'price': price,
      'observedAt': observedAt?.toUtc().toIso8601String(),
      'imageUrl': _nullIfBlank(imageUrl),
      'notes': _nullIfBlank(notes),
    };
  }
}

class AvailabilitySubmissionRequestDto {
  const AvailabilitySubmissionRequestDto({
    required this.productId,
    required this.supermarketId,
    required this.available,
    this.observedAt,
    this.imageUrl,
    this.notes,
  });

  final int productId;
  final int supermarketId;
  final bool available;
  final DateTime? observedAt;
  final String? imageUrl;
  final String? notes;

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'supermarketId': supermarketId,
      'available': available,
      'observedAt': observedAt?.toUtc().toIso8601String(),
      'imageUrl': _nullIfBlank(imageUrl),
      'notes': _nullIfBlank(notes),
    };
  }
}

class SubmissionResponse {
  const SubmissionResponse({
    required this.id,
    required this.type,
    required this.status,
    required this.payload,
    required this.notes,
    required this.reviewReason,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final SubmissionType type;
  final SubmissionStatus status;
  final Map<String, dynamic>? payload;
  final String? notes;
  final String? reviewReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SubmissionResponse.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'];
    return SubmissionResponse(
      id: _toInt(json['id']),
      type: parseSubmissionType(json['type']?.toString()),
      status: parseSubmissionStatus(json['status']?.toString()),
      payload: payload is Map ? payload.cast<String, dynamic>() : null,
      notes: _nullIfBlank(json['notes']?.toString()),
      reviewReason: _nullIfBlank(json['reviewReason']?.toString()),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

String? _nullIfBlank(String? value) {
  if (value == null) {
    return null;
  }
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

String _toString(dynamic value) {
  if (value == null) {
    return '';
  }
  return value.toString().trim();
}

double? _toDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim());
  }
  return null;
}
