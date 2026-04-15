import 'package:cap_app/app/app_router.dart';
import 'package:cap_app/core/utils/formatters.dart';
import 'package:cap_app/features/cart/providers/cart_providers.dart';
import 'package:cap_app/features/catalog/models/catalog_models.dart';
import 'package:cap_app/features/catalog/providers/catalog_providers.dart';
import 'package:cap_app/shared/widgets/android_back_scope.dart';
import 'package:cap_app/shared/widgets/async_value_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({required this.productId, super.key});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(productDetailProvider(productId));
    return BackToHomeScope(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Product Details'),
          actions: [
            IconButton(
              tooltip: 'My Cart',
              onPressed: () => context.push(AppRoutes.cart),
              icon: const Icon(Icons.shopping_cart_outlined),
            ),
          ],
        ),
        body: AsyncValueView<ProductDetailDto>(
          value: detailAsync,
          loadingMessage: 'Loading product details...',
          data: (detail) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  detail.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text('${detail.brand ?? 'Unbranded'} - ${detail.category}'),
                if ((detail.barcode ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Barcode: ${detail.barcode}'),
                ],
                if ((detail.imageUrl ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      detail.imageUrl!,
                      fit: BoxFit.cover,
                      height: 180,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () async {
                    await ref
                        .read(cartNotifierProvider.notifier)
                        .addOrIncrement(
                          productId: detail.id,
                          productName: detail.name,
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Added ${detail.name} to cart'),
                          duration: const Duration(milliseconds: 800),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add_shopping_cart_outlined),
                  label: const Text('Add to cart'),
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: () =>
                      context.push(AppRoutes.submitPrice, extra: detail.id),
                  icon: const Icon(Icons.price_change_outlined),
                  label: const Text('Submit price update'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push(AppRoutes.submitProduct, extra: detail),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Suggest product details edit'),
                ),
                const SizedBox(height: 20),
                _NutritionCard(nutrition: detail.nutrition),
                const SizedBox(height: 16),
                Text(
                  'Verified Prices',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (detail.prices.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('No approved prices yet for this product.'),
                    ),
                  )
                else
                  ...detail.prices.map(
                    (price) => Card(
                      child: ListTile(
                        title: Text(price.supermarketName),
                        subtitle: Text(
                          'Observed ${AppFormatters.asRelativeDateTime(price.observedAt)}',
                        ),
                        trailing: Text(
                          AppFormatters.asCurrency(price.price),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NutritionCard extends StatelessWidget {
  const _NutritionCard({required this.nutrition});

  final ProductNutritionDto? nutrition;

  @override
  Widget build(BuildContext context) {
    if (nutrition == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text('Nutrition information is not available.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nutrition', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _row(
              'Calories',
              nutrition!.calories == null ? '-' : '${nutrition!.calories} kcal',
            ),
            _row(
              'Protein',
              nutrition!.proteinG == null ? '-' : '${nutrition!.proteinG} g',
            ),
            _row(
              'Carbs',
              nutrition!.carbsG == null ? '-' : '${nutrition!.carbsG} g',
            ),
            _row('Fat', nutrition!.fatG == null ? '-' : '${nutrition!.fatG} g'),
            _row('Serving', nutrition!.servingSize ?? '-'),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }
}
