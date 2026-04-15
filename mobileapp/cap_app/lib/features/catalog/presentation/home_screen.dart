import 'dart:async';

import 'package:cap_app/app/app_router.dart';
import 'package:cap_app/core/utils/formatters.dart';
import 'package:cap_app/features/cart/providers/cart_providers.dart';
import 'package:cap_app/features/catalog/models/catalog_models.dart';
import 'package:cap_app/features/catalog/providers/catalog_providers.dart';
import 'package:cap_app/shared/widgets/android_back_scope.dart';
import 'package:cap_app/shared/widgets/async_value_view.dart';
import 'package:cap_app/shared/widgets/main_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productListProvider);
    return HomeExitConfirmScope(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Supermarket Catalog'),
          actions: [
            IconButton(
              tooltip: 'My Cart',
              onPressed: () => context.push(AppRoutes.cart),
              icon: const Icon(Icons.shopping_cart_outlined),
            ),
          ],
        ),
        drawer: const MainDrawer(),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search products by name or brand',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            ref
                                    .read(productSearchQueryProvider.notifier)
                                    .state =
                                '';
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
                onChanged: (value) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 350), () {
                    ref.read(productSearchQueryProvider.notifier).state = value
                        .trim();
                  });
                  setState(() {});
                },
              ),
            ),
            Expanded(
              child: AsyncValueView<List<ProductSummaryDto>>(
                value: productsAsync,
                loadingMessage: 'Loading products...',
                data: (products) {
                  if (products.isEmpty) {
                    return const Center(
                      child: Text('No products found for your search.'),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(productListProvider);
                      await ref.read(productListProvider.future);
                    },
                    child: ListView.separated(
                      itemCount: products.length,
                      separatorBuilder: (_, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return _ProductListTile(product: product);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductListTile extends ConsumerWidget {
  const _ProductListTile({required this.product});

  final ProductSummaryDto product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bestPrice = product.bestPrice;
    final bestPriceLabel = bestPrice == null
        ? 'No verified price yet'
        : '${AppFormatters.asCurrency(bestPrice)} (${product.bestPriceSupermarket ?? '-'})';
    return ListTile(
      onTap: () => context.push(AppRoutes.productDetail(product.id)),
      title: Text(product.name),
      subtitle: Text(
        '${product.brand?.isNotEmpty == true ? product.brand : 'Unbranded'} • ${product.category}\n$bestPriceLabel',
      ),
      isThreeLine: true,
      trailing: IconButton(
        tooltip: 'Add to cart',
        onPressed: () async {
          await ref
              .read(cartNotifierProvider.notifier)
              .addOrIncrement(productId: product.id, productName: product.name);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Added ${product.name} to cart'),
                duration: const Duration(milliseconds: 800),
              ),
            );
          }
        },
        icon: const Icon(Icons.add_shopping_cart_outlined),
      ),
    );
  }
}
