import 'dart:convert';

import 'package:cap_app/core/utils/formatters.dart';
import 'package:cap_app/features/submissions/models/submission_models.dart';
import 'package:cap_app/features/submissions/providers/submission_providers.dart';
import 'package:cap_app/shared/widgets/android_back_scope.dart';
import 'package:cap_app/shared/widgets/async_value_view.dart';
import 'package:cap_app/shared/widgets/main_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MySubmissionsScreen extends ConsumerWidget {
  const MySubmissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissionsAsync = ref.watch(mySubmissionsProvider);
    return BackToHomeScope(
      child: Scaffold(
        appBar: AppBar(title: const Text('My Submissions')),
        drawer: const MainDrawer(),
        body: AsyncValueView<List<SubmissionResponse>>(
          value: submissionsAsync,
          loadingMessage: 'Loading your submissions...',
          data: (items) {
            if (items.isEmpty) {
              return const Center(
                child: Text(
                  'No submissions yet. Use the drawer to submit products or prices.',
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
                  return _SubmissionCard(item: items[index]);
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
  const _SubmissionCard({required this.item});

  final SubmissionResponse item;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (item.status) {
      SubmissionStatus.approved => Colors.green,
      SubmissionStatus.rejected => Colors.red,
      SubmissionStatus.pending => Colors.orange,
      SubmissionStatus.unknown => Colors.grey,
    };

    final typeLabel = item.type.name.toUpperCase();
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
                    'Submission #${item.id} • $typeLabel',
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
            if ((item.notes ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Notes: ${item.notes}'),
            ],
            if (item.payload != null) ...[
              const SizedBox(height: 8),
              Text(
                const JsonEncoder.withIndent('  ').convert(item.payload),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
