import 'package:cap_app/core/utils/formatters.dart';
import 'package:cap_app/features/catalog/providers/catalog_providers.dart';
import 'package:cap_app/features/submissions/models/submission_models.dart';
import 'package:cap_app/features/submissions/providers/submission_providers.dart';
import 'package:cap_app/shared/widgets/android_back_scope.dart';
import 'package:cap_app/shared/widgets/async_value_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MySubmissionsScreen extends ConsumerWidget {
  const MySubmissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissionsAsync = ref.watch(mySubmissionsProvider);
    final productNamesById = ref
        .watch(allProductsProvider)
        .maybeWhen(
          data: (products) => {
            for (final product in products) product.id: product.name,
          },
          orElse: () => const <int, String>{},
        );
    final supermarketNamesById = ref
        .watch(supermarketsProvider)
        .maybeWhen(
          data: (supermarkets) => {
            for (final supermarket in supermarkets)
              supermarket.id: supermarket.name,
          },
          orElse: () => const <int, String>{},
        );
    return BackToHomeScope(
      child: Scaffold(
        appBar: AppBar(title: const Text('My Submissions')),
        body: AsyncValueView<List<SubmissionResponse>>(
          value: submissionsAsync,
          loadingMessage: 'Loading your submissions...',
          data: (items) {
            if (items.isEmpty) {
              return const Center(
                child: Text(
                  'No submissions yet. Use the + button to submit products or prices.',
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(mySubmissionsProvider);
                await ref.read(mySubmissionsProvider.future);
              },
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _SubmissionCard(
                    item: items[index],
                    productNamesById: productNamesById,
                    supermarketNamesById: supermarketNamesById,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({
    required this.item,
    required this.productNamesById,
    required this.supermarketNamesById,
  });

  final SubmissionResponse item;
  final Map<int, String> productNamesById;
  final Map<int, String> supermarketNamesById;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = switch (item.status) {
      SubmissionStatus.approved => colorScheme.primary,
      SubmissionStatus.rejected => colorScheme.error,
      SubmissionStatus.pending => colorScheme.tertiary,
      SubmissionStatus.unknown => colorScheme.outline,
    };

    final typeLabel = _typeLabel(item.type);
    final statusLabel = item.status.name.toUpperCase();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$typeLabel | Ref ${_submissionReference(item)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  backgroundColor: statusColor.withValues(alpha: 0.14),
                  side: BorderSide(color: statusColor.withValues(alpha: 0.6)),
                  label: Text(statusLabel),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Created ${AppFormatters.asRelativeDateTime(item.createdAt)}'),
            const SizedBox(height: 8),
            Text(
              'Your note: ${((item.notes ?? '').trim().isEmpty) ? '-' : item.notes}',
            ),
            const SizedBox(height: 4),
            Text(
              'Moderator note: ${((item.reviewReason ?? '').trim().isEmpty) ? '-' : item.reviewReason}',
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _SubmissionPayloadView(
                item: item,
                productNamesById: productNamesById,
                supermarketNamesById: supermarketNamesById,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmissionPayloadView extends StatelessWidget {
  const _SubmissionPayloadView({
    required this.item,
    required this.productNamesById,
    required this.supermarketNamesById,
  });

  final SubmissionResponse item;
  final Map<int, String> productNamesById;
  final Map<int, String> supermarketNamesById;

  @override
  Widget build(BuildContext context) {
    final payload = item.payload;
    if (payload == null || payload.isEmpty) {
      return const Text('No details provided.');
    }

    return switch (item.type) {
      SubmissionType.product => _ProductPayloadView(
        payload: payload,
        supermarketNamesById: supermarketNamesById,
      ),
      SubmissionType.price => _PricePayloadView(
        payload: payload,
        productNamesById: productNamesById,
        supermarketNamesById: supermarketNamesById,
      ),
      SubmissionType.nutrition => _NutritionPayloadView(
        payload: payload,
        productNamesById: productNamesById,
      ),
      SubmissionType.unknown => _GenericPayloadView(payload: payload),
    };
  }
}

class _ProductPayloadView extends StatelessWidget {
  const _ProductPayloadView({
    required this.payload,
    required this.supermarketNamesById,
  });

  final Map<String, dynamic> payload;
  final Map<int, String> supermarketNamesById;

  @override
  Widget build(BuildContext context) {
    final categoryId = _asInt(payload['categoryId']);
    final sourceProductId = _asInt(payload['sourceProductId']);
    final nutrition = _asMap(payload['nutrition']);
    final imageUrl = _asString(payload['imageUrl']);
    final categoryName = _categoryName(categoryId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sourceProductId == null
              ? 'Product proposal'
              : 'Product update proposal',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        _LabeledValue(label: 'Name', value: _asString(payload['name']) ?? '-'),
        _LabeledValue(
          label: 'Brand',
          value: _asString(payload['brand']) ?? 'Unbranded',
        ),
        _LabeledValue(
          label: 'Category',
          value:
              categoryName ??
              (categoryId == null ? '-' : 'Category #$categoryId'),
        ),
        if (sourceProductId != null)
          _LabeledValue(label: 'Target product', value: '#$sourceProductId'),
        _LabeledValue(
          label: 'Barcode',
          value: _asString(payload['barcode']) ?? '-',
        ),
        _LabeledValue(
          label: 'Supermarket',
          value: _supermarketLabel(
            _asInt(payload['supermarketId']),
            supermarketNamesById,
          ),
        ),
        _LabeledValue(
          label: 'Proposed price',
          value: AppFormatters.asCurrency(_asNum(payload['price'])),
        ),
        if (imageUrl != null && imageUrl.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Image',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              imageUrl,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Text(imageUrl),
            ),
          ),
        ],
        if (nutrition != null && nutrition.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Text(
            'Nutrition per 100g',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          _LabeledValue(
            label: 'Calories',
            value: _formatMeasure(nutrition['calories'], 'kcal'),
          ),
          _LabeledValue(
            label: 'Protein',
            value: _formatMeasure(nutrition['proteinG'], 'g'),
          ),
          _LabeledValue(
            label: 'Carbs',
            value: _formatMeasure(nutrition['carbsG'], 'g'),
          ),
          _LabeledValue(
            label: 'Fat',
            value: _formatMeasure(nutrition['fatG'], 'g'),
          ),
        ],
      ],
    );
  }
}

class _PricePayloadView extends StatelessWidget {
  const _PricePayloadView({
    required this.payload,
    required this.productNamesById,
    required this.supermarketNamesById,
  });

  final Map<String, dynamic> payload;
  final Map<int, String> productNamesById;
  final Map<int, String> supermarketNamesById;

  @override
  Widget build(BuildContext context) {
    final productId = _asInt(payload['productId']);
    final supermarketId = _asInt(payload['supermarketId']);
    final branchId = _asInt(payload['branchId']);
    final observedAt = _asDateTime(payload['observedAt']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Price update proposal',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        _LabeledValue(
          label: 'Product',
          value: _productLabel(productId, productNamesById),
        ),
        _LabeledValue(
          label: 'Supermarket',
          value: _supermarketLabel(supermarketId, supermarketNamesById),
        ),
        if (branchId != null)
          _LabeledValue(label: 'Branch', value: '#$branchId'),
        _LabeledValue(
          label: 'Price',
          value: AppFormatters.asCurrency(_asNum(payload['price'])),
        ),
        _LabeledValue(
          label: 'Observed',
          value: observedAt == null
              ? '-'
              : AppFormatters.asRelativeDateTime(observedAt),
        ),
      ],
    );
  }
}

class _NutritionPayloadView extends StatelessWidget {
  const _NutritionPayloadView({
    required this.payload,
    required this.productNamesById,
  });

  final Map<String, dynamic> payload;
  final Map<int, String> productNamesById;

  @override
  Widget build(BuildContext context) {
    final productId = _asInt(payload['productId']);
    final nutrition = _asMap(payload['nutrition']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nutrition update proposal',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        _LabeledValue(
          label: 'Product',
          value: _productLabel(productId, productNamesById),
        ),
        if (nutrition == null || nutrition.isEmpty)
          const Text('No nutrition fields submitted.')
        else ...[
          _LabeledValue(
            label: 'Calories',
            value: _formatMeasure(nutrition['calories'], 'kcal'),
          ),
          _LabeledValue(
            label: 'Protein',
            value: _formatMeasure(nutrition['proteinG'], 'g'),
          ),
          _LabeledValue(
            label: 'Carbs',
            value: _formatMeasure(nutrition['carbsG'], 'g'),
          ),
          _LabeledValue(
            label: 'Fat',
            value: _formatMeasure(nutrition['fatG'], 'g'),
          ),
        ],
      ],
    );
  }
}

class _GenericPayloadView extends StatelessWidget {
  const _GenericPayloadView({required this.payload});

  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final visibleEntries = payload.entries
        .where((entry) => entry.value is! List && entry.value is! Map)
        .toList();
    if (visibleEntries.isEmpty) {
      return const Text('Details are available, but cannot be previewed.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Submission details',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        ...visibleEntries.map(
          (entry) => _LabeledValue(
            label: entry.key,
            value: _asString(entry.value) ?? '-',
          ),
        ),
      ],
    );
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

String _typeLabel(SubmissionType type) {
  return switch (type) {
    SubmissionType.product => 'PRODUCT',
    SubmissionType.price => 'PRICE',
    SubmissionType.nutrition => 'NUTRITION',
    SubmissionType.unknown => 'UNKNOWN',
  };
}

String _submissionReference(SubmissionResponse item) {
  final typePrefix = switch (item.type) {
    SubmissionType.product => 'PRD',
    SubmissionType.price => 'PRC',
    SubmissionType.nutrition => 'NTR',
    SubmissionType.unknown => 'SUB',
  };
  final created = item.createdAt.toUtc();
  final datePart =
      '${created.year.toString().padLeft(4, '0')}'
      '${created.month.toString().padLeft(2, '0')}'
      '${created.day.toString().padLeft(2, '0')}';
  final safeId = item.id > 0 ? item.id : 0;
  final compactId = safeId.toRadixString(36).toUpperCase().padLeft(4, '0');
  return '$typePrefix-$datePart-$compactId';
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, dynamic>();
  }
  return null;
}

String? _asString(dynamic value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') {
    return null;
  }
  return text;
}

int? _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

num? _asNum(dynamic value) {
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value);
  }
  return null;
}

DateTime? _asDateTime(dynamic value) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
    final numeric = num.tryParse(value);
    if (numeric != null) {
      return _dateTimeFromEpoch(numeric);
    }
    return null;
  }
  if (value is num) {
    return _dateTimeFromEpoch(value);
  }
  return null;
}

DateTime? _dateTimeFromEpoch(num value) {
  if (!value.isFinite) {
    return null;
  }
  final absolute = value.abs();
  final milliseconds = absolute >= 100000000000 ? value : value * 1000;
  return DateTime.fromMillisecondsSinceEpoch(milliseconds.round(), isUtc: true);
}

String _formatMeasure(dynamic value, String unit) {
  final numeric = _asNum(value);
  if (numeric == null) {
    return '-';
  }
  return '$numeric $unit';
}

String _productLabel(int? productId, Map<int, String> namesById) {
  if (productId == null) {
    return '-';
  }
  final name = namesById[productId];
  if (name == null || name.trim().isEmpty) {
    return '#$productId';
  }
  return name;
}

String _supermarketLabel(int? supermarketId, Map<int, String> namesById) {
  if (supermarketId == null) {
    return '-';
  }
  final name = namesById[supermarketId];
  if (name == null || name.trim().isEmpty) {
    return '#$supermarketId';
  }
  return name;
}

String? _categoryName(int? id) {
  if (id == null) {
    return null;
  }
  for (final option in categoryOptions) {
    if (option.id == id) {
      return option.name;
    }
  }
  return null;
}
