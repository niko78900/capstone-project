import 'dart:async';

import 'package:cap_app/app/app_router.dart';
import 'package:cap_app/core/utils/formatters.dart';
import 'package:cap_app/features/cart/providers/cart_providers.dart';
import 'package:cap_app/features/catalog/models/catalog_models.dart';
import 'package:cap_app/features/catalog/providers/catalog_providers.dart';
import 'package:cap_app/shared/widgets/android_back_scope.dart';
import 'package:cap_app/shared/widgets/async_value_view.dart';
import 'package:cap_app/shared/widgets/my_items_icon_button.dart';
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
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Shop',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    const MyItemsIconButton(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by product or brand',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    ref
                                            .read(
                                              productSearchQueryProvider
                                                  .notifier,
                                            )
                                            .state =
                                        '';
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                        ),
                        onChanged: (value) {
                          _debounce?.cancel();
                          _debounce = Timer(
                            const Duration(milliseconds: 350),
                            () {
                              ref
                                  .read(productSearchQueryProvider.notifier)
                                  .state = value
                                  .trim();
                            },
                          );
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Code and barcode tools',
                      onPressed: _openCodeActions,
                      icon: const Icon(Icons.qr_code_scanner),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AsyncValueView<List<ProductSummaryDto>>(
                  value: productsAsync,
                  loadingMessage: 'Loading products...',
                  data: (products) {
                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(productListProvider);
                        await ref.read(productListProvider.future);
                      },
                      child: _ShopProductView(
                        products: products,
                        showPopular: _searchController.text.trim().isEmpty,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCodeActions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (modalContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.numbers_outlined),
                title: const Text('Search by code (manual)'),
                subtitle: const Text('Enter barcode/product code as text'),
                onTap: () {
                  Navigator.of(modalContext).pop();
                  _openManualCodeDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_scanner),
                title: const Text('Scan barcode'),
                subtitle: const Text(
                  'Scanner entry point is ready for integration',
                ),
                onTap: () {
                  Navigator.of(modalContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Scanner placeholder: wire a scanner package when ready.',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openManualCodeDialog() async {
    final controller = TextEditingController();
    final enteredCode = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Search by code'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter barcode or product code',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Search'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    final normalized = (enteredCode ?? '').trim();
    if (normalized.isEmpty) {
      return;
    }

    _searchController.text = normalized;
    ref.read(productSearchQueryProvider.notifier).state = normalized;
    setState(() {});
  }
}

class _ShopProductView extends StatelessWidget {
  const _ShopProductView({required this.products, required this.showPopular});

  final List<ProductSummaryDto> products;
  final bool showPopular;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 20),
          Center(child: Text('No products found for this search.')),
        ],
      );
    }

    final popular = _popularProducts(products);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (showPopular && popular.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Popular Products',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 172,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) =>
                    _PopularProductCard(product: popular[index]),
                separatorBuilder: (_, index) => const SizedBox(width: 10),
                itemCount: popular.length,
              ),
            ),
          ),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: Text(
              showPopular ? 'All Products' : 'Search Results',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          sliver: SliverList.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CatalogProductCard(product: products[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  List<ProductSummaryDto> _popularProducts(List<ProductSummaryDto> input) {
    final sorted = [...input];
    sorted.sort((a, b) {
      final aPrice = a.bestPrice;
      final bPrice = b.bestPrice;
      if (aPrice == null && bPrice == null) {
        return a.name.compareTo(b.name);
      }
      if (aPrice == null) {
        return 1;
      }
      if (bPrice == null) {
        return -1;
      }
      final byPrice = aPrice.compareTo(bPrice);
      if (byPrice != 0) {
        return byPrice;
      }
      return a.name.compareTo(b.name);
    });
    return sorted.take(8).toList();
  }
}

class _PopularProductCard extends StatelessWidget {
  const _PopularProductCard({required this.product});

  final ProductSummaryDto product;

  @override
  Widget build(BuildContext context) {
    final bestPrice = product.bestPrice == null
        ? 'No verified price'
        : AppFormatters.asCurrency(product.bestPrice);

    return SizedBox(
      width: 196,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(AppRoutes.productDetail(product.id)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.category.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  bestPrice,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  product.bestPriceSupermarket ?? 'Awaiting verified market',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogProductCard extends ConsumerWidget {
  const _CatalogProductCard({required this.product});

  final ProductSummaryDto product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bestPrice = product.bestPrice;
    final bestPriceLabel = bestPrice == null
        ? 'No verified price yet'
        : '${AppFormatters.asCurrency(bestPrice)} | ${product.bestPriceSupermarket ?? '-'}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.productDetail(product.id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.category.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                product.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 3),
              Text(
                product.brand?.isNotEmpty == true
                    ? product.brand!
                    : 'Unbranded',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bestPriceLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await ref
                          .read(cartNotifierProvider.notifier)
                          .addOrIncrement(
                            productId: product.id,
                            productName: product.name,
                          );
                      if (context.mounted) {
                        final messenger = ScaffoldMessenger.of(context);
                        messenger.removeCurrentSnackBar();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Added ${product.name} to My Items'),
                            duration: const Duration(milliseconds: 650),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
