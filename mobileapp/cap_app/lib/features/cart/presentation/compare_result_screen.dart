import 'package:cap_app/core/utils/formatters.dart';
import 'package:cap_app/features/cart/models/cart_models.dart';
import 'package:cap_app/features/cart/providers/cart_providers.dart';
import 'package:cap_app/shared/widgets/android_back_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CompareResultScreen extends ConsumerWidget {
  const CompareResultScreen({this.result, super.key});

  final CartComparisonResponse? result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallback = ref.watch(cartComparisonControllerProvider).valueOrNull;
    final resolved = result ?? fallback;

    return BackToHomeScope(
      child: Scaffold(
        appBar: AppBar(title: const Text('Supermarket Comparison')),
        body: resolved == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No comparison result loaded yet.'),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _CheapestBanner(option: resolved.cheapestEligible),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Requested items: ${resolved.requestItemCount} | '
                        'Eligible: ${resolved.diagnostics.eligibleSupermarkets} | '
                        'Partial: ${resolved.diagnostics.partialSupermarkets}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ranked supermarkets',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  ...resolved.rankedSupermarkets.map(
                    (entry) => _ResultCard(entry: entry),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CheapestBanner extends StatelessWidget {
  const _CheapestBanner({required this.option});

  final CheapestEligibleOptionDto? option;

  @override
  Widget build(BuildContext context) {
    if (option == null) {
      return Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            'No single supermarket covers your full item list yet. '
            'See ranked partial options below.',
          ),
        ),
      );
    }
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cheapest eligible option',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '${option!.supermarketName} | ${AppFormatters.asCurrency(option!.totalCost)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.entry});

  final SupermarketCartResultDto entry;

  @override
  Widget build(BuildContext context) {
    final coveragePct = (entry.coverageRatio * 100).toStringAsFixed(0);
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
                    entry.supermarketName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  AppFormatters.asCurrency(entry.totalCost),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              entry.fullCoverage
                  ? 'Full coverage ($coveragePct%)'
                  : 'Partial coverage ($coveragePct%)',
              style: TextStyle(
                color: entry.fullCoverage
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondary,
              ),
            ),
            if (entry.missingItems.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Missing: ${entry.missingItems.map((m) => m.productName).join(', ')}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (entry.lineItems.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ...entry.lineItems.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${line.productName} x ${line.quantity.toStringAsFixed(2)}',
                        ),
                      ),
                      Text(AppFormatters.asCurrency(line.lineTotal)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
