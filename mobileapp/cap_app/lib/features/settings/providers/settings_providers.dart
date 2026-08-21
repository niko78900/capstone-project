// File purpose: Manages Riverpod state for Flutter settings feature flows.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemePreference { system, light, dark }

class AppSettings {
  const AppSettings({
    required this.submissionDecisionNotificationsEnabled,
    required this.themePreference,
    required this.debugModeEnabled,
  });

  final bool submissionDecisionNotificationsEnabled;
  final AppThemePreference themePreference;
  final bool debugModeEnabled;

  AppSettings copyWith({
    bool? submissionDecisionNotificationsEnabled,
    AppThemePreference? themePreference,
    bool? debugModeEnabled,
  }) {
    return AppSettings(
      submissionDecisionNotificationsEnabled:
          submissionDecisionNotificationsEnabled ??
          this.submissionDecisionNotificationsEnabled,
      themePreference: themePreference ?? this.themePreference,
      debugModeEnabled: debugModeEnabled ?? this.debugModeEnabled,
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

final debugModeEnabledProvider = Provider<bool>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.maybeWhen(
    data: (value) => value.debugModeEnabled,
    orElse: () => false,
  );
});

class AppSettingsController extends AsyncNotifier<AppSettings> {
  static const _submissionDecisionNotificationsKey =
      'settings_submission_decision_notifications_enabled';
  static const _themePreferenceKey = 'settings_theme_preference';
  static const _debugModeEnabledKey = 'settings_debug_mode_enabled';

  static const _defaultSettings = AppSettings(
    submissionDecisionNotificationsEnabled: true,
    themePreference: AppThemePreference.system,
    debugModeEnabled: false,
  );

  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final rawThemePreference = prefs.getString(_themePreferenceKey);
    return AppSettings(
      submissionDecisionNotificationsEnabled:
          prefs.getBool(_submissionDecisionNotificationsKey) ?? true,
      themePreference: _parseThemePreference(rawThemePreference),
      debugModeEnabled: prefs.getBool(_debugModeEnabledKey) ?? false,
    );
  }

  Future<void> setSubmissionDecisionNotificationsEnabled(bool enabled) async {
    final current = state.valueOrNull ?? _defaultSettings;
    final next = current.copyWith(
      submissionDecisionNotificationsEnabled: enabled,
    );
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_submissionDecisionNotificationsKey, enabled);
  }

  Future<void> setThemePreference(AppThemePreference preference) async {
    final current = state.valueOrNull ?? _defaultSettings;
    final next = current.copyWith(themePreference: preference);
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePreferenceKey, preference.name);
  }

  Future<void> setDebugModeEnabled(bool enabled) async {
    final current = state.valueOrNull ?? _defaultSettings;
    final next = current.copyWith(debugModeEnabled: enabled);
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_debugModeEnabledKey, enabled);
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
