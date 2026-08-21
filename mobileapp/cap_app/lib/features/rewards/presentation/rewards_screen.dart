// File purpose: Renders Flutter UI for rewards feature workflows.
import 'package:cap_app/core/errors/error_presenter.dart';
import 'package:cap_app/core/utils/formatters.dart';
import 'package:cap_app/features/auth/models/auth_models.dart';
import 'package:cap_app/features/auth/providers/auth_providers.dart';
import 'package:cap_app/features/rewards/models/rewards_models.dart';
import 'package:cap_app/features/rewards/providers/rewards_providers.dart';
import 'package:cap_app/features/settings/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(rewardsDashboardProvider);
    final selectedWindow = ref.watch(rewardWindowProvider);
    final recomputeState = ref.watch(rewardsRecomputeControllerProvider);
    final session = ref.watch(authSessionProvider).valueOrNull;
    final isAdmin = session?.user.role == UserRole.admin;
    final debugModeEnabled = ref.watch(debugModeEnabledProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scoreboard'),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'Recompute scores',
              onPressed: recomputeState.isLoading
                  ? null
                  : () => _recompute(context, ref),
              icon: recomputeState.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              'Contributor Rewards',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Track your score and leaderboard standing.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<RewardWindow>(
              segments: [
                for (final window in RewardWindow.values)
                  ButtonSegment(value: window, label: Text(window.label)),
              ],
              selected: {selectedWindow},
              onSelectionChanged: (selection) {
                ref.read(rewardWindowProvider.notifier).state = selection.first;
              },
            ),
            const SizedBox(height: 16),
            dashboardAsync.when(
              data: (dashboard) => _RewardsDashboardView(dashboard: dashboard),
              loading: () => const _CenteredState(
                icon: Icons.leaderboard_outlined,
                title: 'Loading rewards data...',
                showProgress: true,
              ),
              error: (error, _) => _CenteredState(
                icon: Icons.warning_amber_outlined,
                title: 'Rewards data unavailable',
                message: formatErrorMessageForUi(
                  error,
                  debugModeEnabled: debugModeEnabled,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(rewardsDashboardProvider);
    await ref.read(rewardsDashboardProvider.future);
  }

  Future<void> _recompute(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(rewardsRecomputeControllerProvider.notifier)
        .recompute();
    if (!context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    if (result == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not recompute rewards.')),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Rewards recomputed (${result.rebuiltEvents} event(s), '
          '${result.rebuiltStats} contributor(s)).',
        ),
      ),
    );
  }
}

class _RewardsDashboardView extends StatelessWidget {
  const _RewardsDashboardView({required this.dashboard});

  final RewardsDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final stats = dashboard.me.stats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatsGrid(stats: stats),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Leaderboard',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Top contributors by score.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (dashboard.leaderboard.entries.isEmpty)
                  const _CenteredState(
                    icon: Icons.leaderboard_outlined,
                    title: 'No leaderboard entries',
                    message: 'Reward events have not been generated yet.',
                    compact: true,
                  )
                else
                  for (final entry in dashboard.leaderboard.entries)
                    _LeaderboardRow(entry: entry),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final ContributorStatsDto stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatCard(
          label: 'My score',
          value: stats.score.toString(),
          hint: 'Current contributor score',
        ),
        const SizedBox(height: 10),
        _StatCard(
          label: 'Approved',
          value: stats.approvedTotalCount.toString(),
          hint: 'Approved submissions',
        ),
        const SizedBox(height: 10),
        _StatCard(
          label: 'Rejected',
          value: stats.rejectedCount.toString(),
          hint: 'Rejected submissions',
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 2),
            Text(hint, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry});

  final LeaderboardEntryDto entry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text('#${entry.rank}')),
      title: Text(entry.email),
      subtitle: Text(
        'Approved ${entry.approvedCount} - Rejected ${entry.rejectedCount}\n'
        'Last event ${_formatDate(entry.lastEventAt)}',
      ),
      isThreeLine: true,
      trailing: Text(
        entry.score.toString(),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.title,
    this.message,
    this.showProgress = false,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final bool showProgress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 18 : 72),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showProgress)
            const CircularProgressIndicator()
          else
            Icon(
              icon,
              size: compact ? 32 : 44,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

String _formatDate(DateTime? value) {
  if (value == null) {
    return '-';
  }
  return AppFormatters.asRelativeDateTime(value);
}
