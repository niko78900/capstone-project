import 'package:cap_app/app/app_router.dart';
import 'package:cap_app/features/catalog/models/catalog_models.dart';
import 'package:cap_app/features/catalog/providers/catalog_providers.dart';
import 'package:cap_app/shared/widgets/async_value_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SupermarketsScreen extends ConsumerWidget {
  const SupermarketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supermarketsAsync = ref.watch(supermarketsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Supermarkets')),
      body: AsyncValueView<List<SupermarketDto>>(
        value: supermarketsAsync,
        loadingMessage: 'Loading supermarkets...',
        data: (supermarkets) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(supermarketsProvider);
              await ref.read(supermarketsProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.insights_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Available supermarkets for shopping comparison: ${supermarkets.length}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.cart),
                  icon: const Icon(Icons.compare_arrows),
                  label: const Text('Compare Cart Now'),
                ),
                const SizedBox(height: 16),
                if (supermarkets.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('No supermarkets are available right now.'),
                    ),
                  )
                else
                  ...supermarkets.map(
                    (market) => _SupermarketCard(
                      market: market,
                      onTap: () => context.push(
                        AppRoutes.supermarketProducts(market.id),
                        extra: market.name,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SupermarketCard extends StatelessWidget {
  const _SupermarketCard({required this.market, required this.onTap});

  final SupermarketDto market;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.storefront_outlined),
        ),
        title: Text(market.name),
        subtitle: const Text('Included in verified price comparison results'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
