import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemePreference { system, light, dark }

class AppSettings {
  const AppSettings({
    required this.submissionDecisionNotificationsEnabled,
    required this.themePreference,
  });

  final bool submissionDecisionNotificationsEnabled;
  final AppThemePreference themePreference;

  AppSettings copyWith({
    bool? submissionDecisionNotificationsEnabled,
    AppThemePreference? themePreference,
  }) {
    return AppSettings(
      submissionDecisionNotificationsEnabled:
          submissionDecisionNotificationsEnabled ??
          this.submissionDecisionNotificationsEnabled,
      themePreference: themePreference ?? this.themePreference,
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

final themeModeProvider = Provider<ThemeMode>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.maybeWhen(
    data: (value) => value.themePreference.toThemeMode(),
    orElse: () => ThemeMode.system,
  );
});

class AppSettingsController extends AsyncNotifier<AppSettings> {
  static const _submissionDecisionNotificationsKey =
      'settings_submission_decision_notifications_enabled';
  static const _themePreferenceKey = 'settings_theme_preference';

  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final rawThemePreference = prefs.getString(_themePreferenceKey);
    return AppSettings(
      submissionDecisionNotificationsEnabled:
          prefs.getBool(_submissionDecisionNotificationsKey) ?? true,
      themePreference: _parseThemePreference(rawThemePreference),
    );
  }

  Future<void> setSubmissionDecisionNotificationsEnabled(bool enabled) async {
    final current = state.valueOrNull ??
        const AppSettings(
          submissionDecisionNotificationsEnabled: true,
          themePreference: AppThemePreference.system,
        );
    final next = current.copyWith(
      submissionDecisionNotificationsEnabled: enabled,
    );
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_submissionDecisionNotificationsKey, enabled);
  }

  Future<void> setThemePreference(AppThemePreference preference) async {
    final current = state.valueOrNull ??
        const AppSettings(
          submissionDecisionNotificationsEnabled: true,
          themePreference: AppThemePreference.system,
        );
    final next = current.copyWith(themePreference: preference);
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePreferenceKey, preference.name);
  }
}

AppThemePreference _parseThemePreference(String? value) {
  switch ((value ?? '').toLowerCase()) {
    case 'light':
      return AppThemePreference.light;
    case 'dark':
      return AppThemePreference.dark;
    default:
      return AppThemePreference.system;
  }
}

extension on AppThemePreference {
  ThemeMode toThemeMode() {
    return switch (this) {
      AppThemePreference.system => ThemeMode.system,
      AppThemePreference.light => ThemeMode.light,
      AppThemePreference.dark => ThemeMode.dark,
    };
  }
}
