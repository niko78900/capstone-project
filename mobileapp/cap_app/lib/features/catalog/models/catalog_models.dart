class ProductNutritionDto {
  const ProductNutritionDto({
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

  factory ProductNutritionDto.fromJson(Map<String, dynamic> json) {
    return ProductNutritionDto(
      calories: _toDouble(json['calories']),
      proteinG: _toDouble(json['proteinG']),
      carbsG: _toDouble(json['carbsG']),
      fatG: _toDouble(json['fatG']),
      servingSize: _toNullableString(json['servingSize']),
    );
  }

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

class ProductPriceDto {
  const ProductPriceDto({
    required this.supermarketId,
    required this.supermarketName,
    required this.price,
    required this.currency,
    required this.observedAt,
  });

  final int supermarketId;
  final String supermarketName;
  final double price;
  final String currency;
  final DateTime observedAt;

  factory ProductPriceDto.fromJson(Map<String, dynamic> json) {
    return ProductPriceDto(
      supermarketId: _toInt(json['supermarketId']),
      supermarketName: _toString(json['supermarketName']),
      price: _toDouble(json['price']) ?? 0,
      currency: _toString(json['currency'], fallback: 'MKD'),
      observedAt:
          DateTime.tryParse(_toString(json['observedAt'])) ??
          DateTime.now().toUtc(),
    );
  }
}

class ProductPriceHistoryPointDto {
  const ProductPriceHistoryPointDto({
    required this.supermarketId,
    required this.supermarketName,
    required this.price,
    required this.currency,
    required this.observedAt,
  });

  final int supermarketId;
  final String supermarketName;
  final double price;
  final String currency;
  final DateTime observedAt;

  factory ProductPriceHistoryPointDto.fromJson(Map<String, dynamic> json) {
    return ProductPriceHistoryPointDto(
      supermarketId: _toInt(json['supermarketId']),
      supermarketName: _toString(json['supermarketName']),
      price: _toDouble(json['price']) ?? 0,
      currency: _toString(json['currency'], fallback: 'MKD'),
      observedAt:
          DateTime.tryParse(_toString(json['observedAt'])) ??
          DateTime.now().toUtc(),
    );
  }
}

class ProductSummaryDto {
  const ProductSummaryDto({
    required this.id,
    required this.name,
    this.brand,
    this.barcode,
    required this.category,
    this.nutrition,
    this.bestPrice,
    this.bestPriceSupermarket,
    this.currency,
  });

  final int id;
  final String name;
  final String? brand;
  final String? barcode;
  final String category;
  final ProductNutritionDto? nutrition;
  final double? bestPrice;
  final String? bestPriceSupermarket;
  final String? currency;

  factory ProductSummaryDto.fromJson(Map<String, dynamic> json) {
    final nutritionRaw = json['nutrition'];
    return ProductSummaryDto(
      id: _toInt(json['id']),
      name: _toString(json['name']),
      brand: _toNullableString(json['brand']),
      barcode: _toNullableString(json['barcode']),
      category: _toString(json['category']),
      nutrition: nutritionRaw is Map
          ? ProductNutritionDto.fromJson(nutritionRaw.cast<String, dynamic>())
          : null,
      bestPrice: _toDouble(json['bestPrice']),
      bestPriceSupermarket: _toNullableString(json['bestPriceSupermarket']),
      currency: _toNullableString(json['currency']),
    );
  }
}

class ProductDetailDto {
  const ProductDetailDto({
    required this.id,
    required this.name,
    this.brand,
    this.barcode,
    this.imageUrl,
    required this.category,
    this.nutrition,
    required this.prices,
    this.priceHistory = const [],
  });

  final int id;
  final String name;
  final String? brand;
  final String? barcode;
  final String? imageUrl;
  final String category;
  final ProductNutritionDto? nutrition;
  final List<ProductPriceDto> prices;
  final List<ProductPriceHistoryPointDto> priceHistory;

  factory ProductDetailDto.fromJson(Map<String, dynamic> json) {
    final nutritionRaw = json['nutrition'];
    final pricesRaw = json['prices'];
    final priceHistoryRaw = json['priceHistory'];
    return ProductDetailDto(
      id: _toInt(json['id']),
      name: _toString(json['name']),
      brand: _toNullableString(json['brand']),
      barcode: _toNullableString(json['barcode']),
      imageUrl: _toNullableString(json['imageUrl']),
      category: _toString(json['category']),
      nutrition: nutritionRaw is Map
          ? ProductNutritionDto.fromJson(nutritionRaw.cast<String, dynamic>())
          : null,
      prices: pricesRaw is List
          ? pricesRaw
                .whereType<Map>()
                .map(
                  (item) =>
                      ProductPriceDto.fromJson(item.cast<String, dynamic>()),
                )
                .toList()
          : const [],
      priceHistory: priceHistoryRaw is List
          ? priceHistoryRaw
                .whereType<Map>()
                .map(
                  (item) => ProductPriceHistoryPointDto.fromJson(
                    item.cast<String, dynamic>(),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

class SupermarketDto {
  const SupermarketDto({required this.id, required this.name});

  final int id;
  final String name;

  factory SupermarketDto.fromJson(Map<String, dynamic> json) {
    return SupermarketDto(
      id: _toInt(json['id']),
      name: _toString(json['name']),
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

double? _toDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

String _toString(dynamic value, {String fallback = ''}) {
  final raw = value?.toString() ?? fallback;
  return raw;
}

String? _toNullableString(dynamic value) {
  final str = value?.toString().trim();
  if (str == null || str.isEmpty) {
    return null;
  }
  return str;
}
