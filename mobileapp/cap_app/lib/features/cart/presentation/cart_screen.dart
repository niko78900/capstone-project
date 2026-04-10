import 'package:cap_app/app/app_router.dart';
import 'package:cap_app/features/cart/models/cart_models.dart';
import 'package:cap_app/features/cart/providers/cart_providers.dart';
import 'package:cap_app/shared/widgets/async_value_view.dart';
import 'package:cap_app/shared/widgets/main_drawer.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart'),
        actions: [
          IconButton(
            tooltip: 'Clear cart',
            onPressed: () => ref.read(cartNotifierProvider.notifier).clear(),
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      drawer: const MainDrawer(),
      body: AsyncValueView<List<CartItem>>(
        value: cartAsync,
        loadingMessage: 'Loading your cart...',
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Your cart is empty. Add products from the catalog.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => context.go(AppRoutes.home),
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
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _CartItemTile(item: item);
                  },
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
                    label: Text(isComparing ? 'Comparing...' : 'Compare Single-Supermarket Options'),
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

class _CartItemTile extends ConsumerWidget {
  const _CartItemTile({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(item.productName),
      subtitle: Text('Quantity: ${item.quantity.toStringAsFixed(2)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Decrease',
            onPressed: () => ref.read(cartNotifierProvider.notifier).decrement(item.productId),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          IconButton(
            tooltip: 'Increase',
            onPressed: () => ref.read(cartNotifierProvider.notifier).addOrIncrement(
                  productId: item.productId,
                  productName: item.productName,
                ),
            icon: const Icon(Icons.add_circle_outline),
          ),
          IconButton(
            tooltip: 'Remove item',
            onPressed: () => ref.read(cartNotifierProvider.notifier).remove(item.productId),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}
