// File purpose: Manages Riverpod state for Flutter catalog feature flows.
import 'package:cap_app/core/network/network_providers.dart';
import 'package:cap_app/features/auth/providers/auth_providers.dart';
import 'package:cap_app/features/catalog/data/catalog_repository.dart';
import 'package:cap_app/features/catalog/models/catalog_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(ref.read(apiClientProvider));
});

final productSearchQueryProvider = StateProvider<String>((ref) => '');
final supermarketSearchQueryProvider = StateProvider.family<String, int>(
  (ref, supermarketId) => '',
);

final productListProvider = FutureProvider<List<ProductSummaryDto>>((
  ref,
) async {
  ref.watch(
    authSessionProvider.select((state) => state.valueOrNull?.accessToken),
  );
  final query = ref.watch(productSearchQueryProvider);
  final repo = ref.watch(catalogRepositoryProvider);
  try {
    return await repo.getProducts(query: query);
  } catch (error) {
    await ref
        .read(authSessionProvider.notifier)
        .forceLogoutOnUnauthorized(error);
    rethrow;
  }
});

final allProductsProvider = FutureProvider<List<ProductSummaryDto>>((
  ref,
) async {
  ref.watch(
    authSessionProvider.select((state) => state.valueOrNull?.accessToken),
  );
  final repo = ref.watch(catalogRepositoryProvider);
  try {
    return await repo.getProducts();
  } catch (error) {
    await ref
        .read(authSessionProvider.notifier)
        .forceLogoutOnUnauthorized(error);
    rethrow;
  }
});

final supermarketProductListProvider =
    FutureProvider.family<List<ProductSummaryDto>, int>((
      ref,
      supermarketId,
    ) async {
      ref.watch(
        authSessionProvider.select((state) => state.valueOrNull?.accessToken),
      );
      final query = ref.watch(supermarketSearchQueryProvider(supermarketId));
      final repo = ref.watch(catalogRepositoryProvider);
      try {
        return await repo.getProducts(
          query: query,
          supermarketId: supermarketId,
        );
      } catch (error) {
        await ref
            .read(authSessionProvider.notifier)
            .forceLogoutOnUnauthorized(error);
        rethrow;
      }
    });

final productDetailProvider = FutureProvider.family<ProductDetailDto, int>((
  ref,
  productId,
) async {
  ref.watch(
    authSessionProvider.select((state) => state.valueOrNull?.accessToken),
  );
  final repo = ref.watch(catalogRepositoryProvider);
  try {
    return await repo.getProductDetail(productId);
  } catch (error) {
    await ref
        .read(authSessionProvider.notifier)
        .forceLogoutOnUnauthorized(error);
    rethrow;
  }
});

final supermarketsProvider = FutureProvider<List<SupermarketDto>>((ref) async {
  ref.watch(
    authSessionProvider.select((state) => state.valueOrNull?.accessToken),
  );
  final repo = ref.watch(catalogRepositoryProvider);
  try {
    return await repo.getSupermarkets();
  } catch (error) {
    await ref
        .read(authSessionProvider.notifier)
        .forceLogoutOnUnauthorized(error);
    rethrow;
  }
});
