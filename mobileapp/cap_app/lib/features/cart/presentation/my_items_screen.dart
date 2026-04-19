import 'package:cap_app/app/app_router.dart';
import 'package:cap_app/core/utils/formatters.dart';
import 'package:cap_app/features/cart/models/cart_models.dart';
import 'package:cap_app/features/cart/providers/cart_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MyItemsScreen extends ConsumerWidget {
  const MyItemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentItemsAsync = ref.watch(recentCartItemsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Items'),
        actions: [
          IconButton(
            tooltip: 'Open cart',
            onPressed: () => context.push(AppRoutes.cart),
            icon: const Icon(Icons.shopping_basket_outlined),
          ),
        ],
      ),
      body: recentItemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Failed to load item history: $error'),
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
                      Icons.history_outlined,
                      size: 42,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    const Text('No recent items yet.'),
                    const SizedBox(height: 6),
                    const Text(
                      'Add products to your cart from Shop, then re-add them from here later.',
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

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.replay_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Re-add products you recently placed in cart.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...items.map((item) => _RecentItemCard(item: item)),
            ],
          );
        },
      ),
    );
  }
}

class _RecentItemCard extends ConsumerWidget {
  const _RecentItemCard({required this.item});

  final RecentCartItem item;

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
            Text(
              'Last added: ${AppFormatters.asRelativeDateTime(item.lastAddedAt)}',
            ),
            Text('Added ${item.addCount} time(s)'),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await ref
                        .read(cartNotifierProvider.notifier)
                        .addOrIncrement(
                          productId: item.productId,
                          productName: item.productName,
                        );
                    if (context.mounted) {
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.removeCurrentSnackBar();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Added ${item.productName} to cart'),
                          duration: const Duration(milliseconds: 700),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add again'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => ref
                      .read(recentCartItemsProvider.notifier)
                      .removeFromHistory(item.productId),
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
}
