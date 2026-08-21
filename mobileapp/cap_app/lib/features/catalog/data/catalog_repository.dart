// File purpose: Connects Flutter catalog feature code to backend or local data sources.
import 'package:cap_app/core/network/api_client.dart';
import 'package:cap_app/features/catalog/models/catalog_models.dart';

class CatalogRepository {
  CatalogRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ProductSummaryDto>> getProducts({
    String? query,
    int? supermarketId,
  }) async {
    final queryParameters = <String, dynamic>{};
    if (query != null && query.trim().isNotEmpty) {
      queryParameters['q'] = query.trim();
    }
    if (supermarketId != null) {
      queryParameters['supermarketId'] = supermarketId;
    }

    final raw = await _apiClient.get(
      '/api/v1/products',
      queryParameters: queryParameters,
    );
    if (raw is! List) {
      return const [];
    }
    return raw
        .whereType<Map>()
        .map((item) => ProductSummaryDto.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<ProductDetailDto> getProductDetail(int id) async {
    final raw = await _apiClient.get('/api/v1/products/$id');
    return ProductDetailDto.fromJson((raw as Map).cast<String, dynamic>());
  }

  Future<List<SupermarketDto>> getSupermarkets() async {
    final raw = await _apiClient.get('/api/v1/supermarkets');
    if (raw is! List) {
      return const [];
    }
    return raw
        .whereType<Map>()
        .map((item) => SupermarketDto.fromJson(item.cast<String, dynamic>()))
        .toList();
  }
}
