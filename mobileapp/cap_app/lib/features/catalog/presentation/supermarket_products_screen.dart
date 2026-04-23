import 'dart:async';

import 'package:cap_app/app/app_router.dart';
import 'package:cap_app/core/utils/formatters.dart';
import 'package:cap_app/features/catalog/models/catalog_models.dart';
import 'package:cap_app/features/catalog/providers/catalog_providers.dart';
import 'package:cap_app/shared/widgets/async_value_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SupermarketProductsScreen extends ConsumerStatefulWidget {
  const SupermarketProductsScreen({
    required this.supermarketId,
    this.supermarketName,
    super.key,
  });

  final int supermarketId;
  final String? supermarketName;

  @override
  ConsumerState<SupermarketProductsScreen> createState() =>
      _SupermarketProductsScreenState();
}

class _SupermarketProductsScreenState
    extends ConsumerState<SupermarketProductsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    ref
            .read(supermarketSearchQueryProvider(widget.supermarketId).notifier)
            .state =
        '';
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(
      supermarketProductListProvider(widget.supermarketId),
    );
    final marketName = widget.supermarketName ?? 'Selected supermarket';

    return Scaffold(
      appBar: AppBar(title: Text(marketName)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search items in $marketName',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.clear),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _searchController.text.trim().isEmpty
                    ? 'All available items in $marketName'
                    : 'Search results in $marketName',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: AsyncValueView<List<ProductSummaryDto>>(
              value: productsAsync,
              loadingMessage: 'Loading items...',
              onRefresh: _refresh,
              data: (products) {
                if (products.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: const [
                        SizedBox(height: 24),
                        Center(
                          child: Text(
                            'No items found for this supermarket and search.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemBuilder: (context, index) {
                      return _SupermarketProductCard(product: products[index]);
                    },
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemCount: products.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref
          .read(supermarketSearchQueryProvider(widget.supermarketId).notifier)
          .state = value
          .trim();
    });
    setState(() {});
  }

  void _clearSearch() {
    _searchController.clear();
    ref
            .read(supermarketSearchQueryProvider(widget.supermarketId).notifier)
            .state =
        '';
    setState(() {});
  }

  Future<void> _refresh() async {
    ref.invalidate(supermarketProductListProvider(widget.supermarketId));
    await ref.read(supermarketProductListProvider(widget.supermarketId).future);
  }
}

class _SupermarketProductCard extends StatelessWidget {
  const _SupermarketProductCard({required this.product});

  final ProductSummaryDto product;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: () => context.push(AppRoutes.productDetail(product.id)),
        title: Text(product.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.brand?.trim().isNotEmpty == true
                  ? product.brand!
                  : 'Unbranded',
            ),
            Text(product.category),
            if (product.bestPrice != null)
              Text(
                'Best verified: ${AppFormatters.asCurrency(product.bestPrice)}',
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
