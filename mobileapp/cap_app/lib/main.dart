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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
