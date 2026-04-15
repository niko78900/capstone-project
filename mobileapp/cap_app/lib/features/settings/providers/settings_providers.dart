import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({
    required this.submissionDecisionNotificationsEnabled,
  });

  final bool submissionDecisionNotificationsEnabled;

  AppSettings copyWith({
    bool? submissionDecisionNotificationsEnabled,
  }) {
    return AppSettings(
      submissionDecisionNotificationsEnabled:
          submissionDecisionNotificationsEnabled ??
          this.submissionDecisionNotificationsEnabled,
    );
  }
}

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

final submissionDecisionNotificationsEnabledProvider = Provider<bool>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.maybeWhen(
    data: (value) => value.submissionDecisionNotificationsEnabled,
    orElse: () => true,
  );
});

class AppSettingsController extends AsyncNotifier<AppSettings> {
  static const _submissionDecisionNotificationsKey =
      'settings_submission_decision_notifications_enabled';

  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      submissionDecisionNotificationsEnabled:
          prefs.getBool(_submissionDecisionNotificationsKey) ?? true,
    );
  }

  Future<void> setSubmissionDecisionNotificationsEnabled(bool enabled) async {
    final current = state.valueOrNull ??
        const AppSettings(submissionDecisionNotificationsEnabled: true);
    final next = current.copyWith(
      submissionDecisionNotificationsEnabled: enabled,
    );
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_submissionDecisionNotificationsKey, enabled);
  }
}
