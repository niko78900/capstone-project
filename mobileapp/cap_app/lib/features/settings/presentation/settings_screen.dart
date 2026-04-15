import 'package:cap_app/features/settings/providers/settings_providers.dart';
import 'package:cap_app/shared/widgets/android_back_scope.dart';
import 'package:cap_app/shared/widgets/main_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final enabled = settings.maybeWhen(
      data: (value) => value.submissionDecisionNotificationsEnabled,
      orElse: () => true,
    );
    final loading = settings.isLoading;

    return BackToHomeScope(
      child: Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        drawer: const MainDrawer(),
        body: ListView(
          children: [
            SwitchListTile(
              title: const Text('Submission decision notifications'),
              subtitle: const Text(
                'Notify when your submission is approved or rejected.',
              ),
              value: enabled,
              onChanged: loading
                  ? null
                  : (value) async {
                      await ref
                          .read(appSettingsProvider.notifier)
                          .setSubmissionDecisionNotificationsEnabled(value);
                    },
            ),
          ],
        ),
      ),
    );
  }
}
