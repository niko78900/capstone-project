import 'dart:convert';

class CartItem {
  const CartItem({
    required this.productId,
    required this.productName,
    required this.quantity,
  });

  final int productId;
  final String productName;
  final double quantity;

  CartItem copyWith({
    int? productId,
    String? productName,
    double? quantity,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: _toInt(json['productId']),
      productName: _toString(json['productName']),
      quantity: _toDouble(json['quantity']) ?? 1,
    );
  }

  static String encodeList(List<CartItem> items) {
    return jsonEncode(items.map((item) => item.toJson()).toList());
  }

  static List<CartItem> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }
    return decoded.whereType<Map>().map((item) => CartItem.fromJson(item.cast<String, dynamic>())).toList();
  }
}

class CartCompareItemRequest {
  const CartCompareItemRequest({
    required this.productId,
    required this.quantity,
  });

  final int productId;
  final double quantity;

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'quantity': quantity,
    };
  }
}

class CartComparisonResponse {
  const CartComparisonResponse({
    required this.requestItemCount,
    required this.cheapestEligible,
    required this.rankedSupermarkets,
    required this.diagnostics,
  });

  final int requestItemCount;
  final CheapestEligibleOptionDto? cheapestEligible;
  final List<SupermarketCartResultDto> rankedSupermarkets;
  final CartDiagnosticsDto diagnostics;

  factory CartComparisonResponse.fromJson(Map<String, dynamic> json) {
    final cheapestRaw = json['cheapestEligible'];
    final rankedRaw = json['rankedSupermarkets'];
    final diagnosticsRaw = json['diagnostics'];
    return CartComparisonResponse(
      requestItemCount: _toInt(json['requestItemCount']),
      cheapestEligible: cheapestRaw is Map
          ? CheapestEligibleOptionDto.fromJson(cheapestRaw.cast<String, dynamic>())
          : null,
      rankedSupermarkets: rankedRaw is List
          ? rankedRaw
              .whereType<Map>()
              .map((item) => SupermarketCartResultDto.fromJson(item.cast<String, dynamic>()))
              .toList()
          : const [],
      diagnostics: diagnosticsRaw is Map
          ? CartDiagnosticsDto.fromJson(diagnosticsRaw.cast<String, dynamic>())
          : const CartDiagnosticsDto(
              eligibleSupermarkets: 0,
              partialSupermarkets: 0,
              totalSupermarkets: 0,
            ),
    );
  }
}

class CheapestEligibleOptionDto {
  const CheapestEligibleOptionDto({
    required this.supermarketId,
    required this.supermarketName,
    required this.totalCost,
    required this.currency,
  });

  final int supermarketId;
  final String supermarketName;
  final double totalCost;
  final String currency;

  factory CheapestEligibleOptionDto.fromJson(Map<String, dynamic> json) {
    return CheapestEligibleOptionDto(
      supermarketId: _toInt(json['supermarketId']),
      supermarketName: _toString(json['supermarketName']),
      totalCost: _toDouble(json['totalCost']) ?? 0,
      currency: _toString(json['currency'], fallback: 'MKD'),
    );
  }
}

class SupermarketCartResultDto {
  const SupermarketCartResultDto({
    required this.supermarketId,
    required this.supermarketName,
    required this.totalCost,
    required this.currency,
    required this.fullCoverage,
    required this.coverageRatio,
    required this.missingItems,
    required this.lineItems,
  });

  final int supermarketId;
  final String supermarketName;
  final double totalCost;
  final String currency;
  final bool fullCoverage;
  final double coverageRatio;
  final List<MissingCartItemDto> missingItems;
  final List<CartLineItemDto> lineItems;

  factory SupermarketCartResultDto.fromJson(Map<String, dynamic> json) {
    final missingRaw = json['missingItems'];
    final linesRaw = json['lineItems'];
    return SupermarketCartResultDto(
      supermarketId: _toInt(json['supermarketId']),
      supermarketName: _toString(json['supermarketName']),
      totalCost: _toDouble(json['totalCost']) ?? 0,
      currency: _toString(json['currency'], fallback: 'MKD'),
      fullCoverage: json['fullCoverage'] == true,
      coverageRatio: _toDouble(json['coverageRatio']) ?? 0,
      missingItems: missingRaw is List
          ? missingRaw.whereType<Map>().map((item) => MissingCartItemDto.fromJson(item.cast<String, dynamic>())).toList()
          : const [],
      lineItems: linesRaw is List
          ? linesRaw.whereType<Map>().map((item) => CartLineItemDto.fromJson(item.cast<String, dynamic>())).toList()
          : const [],
    );
  }
}

class MissingCartItemDto {
  const MissingCartItemDto({
    required this.productId,
    required this.productName,
  });

  final int productId;
  final String productName;

  factory MissingCartItemDto.fromJson(Map<String, dynamic> json) {
    return MissingCartItemDto(
      productId: _toInt(json['productId']),
      productName: _toString(json['productName']),
    );
  }
}

class CartLineItemDto {
  const CartLineItemDto({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final int productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double lineTotal;

  factory CartLineItemDto.fromJson(Map<String, dynamic> json) {
    return CartLineItemDto(
      productId: _toInt(json['productId']),
      productName: _toString(json['productName']),
      quantity: _toDouble(json['quantity']) ?? 0,
      unitPrice: _toDouble(json['unitPrice']) ?? 0,
      lineTotal: _toDouble(json['lineTotal']) ?? 0,
    );
  }
}

class CartDiagnosticsDto {
  const CartDiagnosticsDto({
    required this.eligibleSupermarkets,
    required this.partialSupermarkets,
    required this.totalSupermarkets,
  });

  final int eligibleSupermarkets;
  final int partialSupermarkets;
  final int totalSupermarkets;

  factory CartDiagnosticsDto.fromJson(Map<String, dynamic> json) {
    return CartDiagnosticsDto(
      eligibleSupermarkets: _toInt(json['eligibleSupermarkets']),
      partialSupermarkets: _toInt(json['partialSupermarkets']),
      totalSupermarkets: _toInt(json['totalSupermarkets']),
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
