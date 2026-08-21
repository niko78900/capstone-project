// File purpose: Renders Flutter UI for cart feature workflows.
import 'package:cap_app/app/app_router.dart';
import 'package:cap_app/core/errors/error_presenter.dart';
import 'package:cap_app/features/cart/models/cart_models.dart';
import 'package:cap_app/features/cart/providers/cart_providers.dart';
import 'package:cap_app/features/settings/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartNotifierProvider);
    final compareState = ref.watch(cartComparisonControllerProvider);
    final isComparing = compareState.isLoading;
    final debugModeEnabled = ref.watch(debugModeEnabledProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
        actions: [
          IconButton(
            tooltip: 'Clear cart',
            onPressed: () => ref.read(cartNotifierProvider.notifier).clear(),
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: cartAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              formatErrorMessageForUi(
                error,
                debugModeEnabled: debugModeEnabled,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shopping_basket_outlined,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    const Text('Your cart is empty.'),
                    const SizedBox(height: 6),
                    const Text(
                      'Add products from Shop, then compare totals across supermarkets.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () => context.go(AppRoutes.shop),
                      child: const Text('Browse products'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${items.length} selected item(s). Adjust quantities before comparing.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...items.map((item) => _MyItemCard(item: item)),
                  ],
                ),
              ),
              SafeArea(
                minimum: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isComparing
                        ? null
                        : () async {
                            final result = await ref
                                .read(cartComparisonControllerProvider.notifier)
                                .compare(items);
                            if (result == null || !context.mounted) {
                              return;
                            }
                            context.push(
                              AppRoutes.compareResult,
                              extra: result,
                            );
                          },
                    icon: isComparing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.compare_arrows),
                    label: Text(
                      isComparing
                          ? 'Comparing...'
                          : 'Compare totals across supermarkets',
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MyItemCard extends ConsumerWidget {
  const _MyItemCard({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.productName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text('Quantity: ${_displayQuantity(item.quantity)}'),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Decrease quantity',
                  onPressed: () => ref
                      .read(cartNotifierProvider.notifier)
                      .decrement(item.productId),
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Increase quantity',
                  onPressed: () => ref
                      .read(cartNotifierProvider.notifier)
                      .addOrIncrement(
                        productId: item.productId,
                        productName: item.productName,
                      ),
                  icon: const Icon(Icons.add),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => ref
                      .read(cartNotifierProvider.notifier)
                      .remove(item.productId),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _displayQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }
}
