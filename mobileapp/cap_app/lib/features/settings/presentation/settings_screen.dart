import 'package:cap_app/features/settings/providers/settings_providers.dart';
import 'package:cap_app/shared/widgets/android_back_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final themePreference = settings.maybeWhen(
      data: (value) => value.themePreference,
      orElse: () => AppThemePreference.system,
    );
    final enabled = settings.maybeWhen(
      data: (value) => value.submissionDecisionNotificationsEnabled,
      orElse: () => true,
    );
    final debugModeEnabled = settings.maybeWhen(
      data: (value) => value.debugModeEnabled,
      orElse: () => false,
    );
    final loading = settings.isLoading;

    return BackToHomeScope(
      child: Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Appearance',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: DropdownButtonFormField<AppThemePreference>(
                initialValue: themePreference,
                decoration: const InputDecoration(
                  labelText: 'Theme',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: AppThemePreference.system,
                    child: Text('Follow phone theme'),
                  ),
                  DropdownMenuItem(
                    value: AppThemePreference.light,
                    child: Text('Light'),
                  ),
                  DropdownMenuItem(
                    value: AppThemePreference.dark,
                    child: Text('Dark'),
                  ),
                ],
                onChanged: loading
                    ? null
                    : (value) async {
                        if (value == null) {
                          return;
                        }
                        await ref
                            .read(appSettingsProvider.notifier)
                            .setThemePreference(value);
                      },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Choose how the app handles light and dark appearance.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const Divider(height: 1),
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
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Debug mode'),
              subtitle: const Text(
                'Show technical exception details together with user-friendly errors.',
              ),
              value: debugModeEnabled,
              onChanged: loading
                  ? null
                  : (value) async {
                      await ref
                          .read(appSettingsProvider.notifier)
                          .setDebugModeEnabled(value);
                    },
            ),
          ],
        ),
      ),
    );
  }
}
