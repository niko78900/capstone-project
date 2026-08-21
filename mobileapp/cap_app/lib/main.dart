// File purpose: Defines Flutter behavior for main.
import 'package:cap_app/app/app_router.dart';
import 'package:cap_app/features/settings/providers/settings_providers.dart';
import 'package:cap_app/features/submissions/providers/submission_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: CapstoneApp()));
}

class CapstoneApp extends ConsumerWidget {
  const CapstoneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(submissionNotificationBootstrapProvider);
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    const seedColor = Color(0xFF1A7F64);
    return MaterialApp.router(
      title: 'Capstone Supermarket',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(seedColor: seedColor, brightness: Brightness.light),
      darkTheme: _buildTheme(seedColor: seedColor, brightness: Brightness.dark),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

ThemeData _buildTheme({
  required Color seedColor,
  required Brightness brightness,
}) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: colorScheme.surface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surface,
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      floatingLabelStyle: TextStyle(color: colorScheme.primary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
