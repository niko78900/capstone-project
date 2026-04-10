import 'package:cap_app/core/network/api_client.dart';
import 'package:cap_app/features/cart/models/cart_models.dart';

class CartRepository {
  CartRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<CartComparisonResponse> compareSingleSupermarket(List<CartCompareItemRequest> items) async {
    final raw = await _apiClient.post(
      '/api/v1/cart/compare/single-supermarket',
      data: {
        'items': items.map((item) => item.toJson()).toList(),
      },
    );
    return CartComparisonResponse.fromJson((raw as Map).cast<String, dynamic>());
  }
}
