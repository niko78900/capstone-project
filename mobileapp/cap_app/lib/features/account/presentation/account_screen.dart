import 'package:cap_app/app/app_router.dart';
import 'package:cap_app/features/auth/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session?.user.displayName ?? 'Guest',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(session?.user.email ?? '-'),
                  const SizedBox(height: 4),
                  Text(
                    'Role: ${session?.user.role.name.toUpperCase() ?? 'USER'}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.inbox_outlined),
                  title: const Text('My Submissions'),
                  subtitle: const Text(
                    'Track pending, approved, and rejected updates',
                  ),
                  onTap: () => context.push(AppRoutes.submissions),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings'),
                  subtitle: const Text('Theme and notification preferences'),
                  onTap: () => context.push(AppRoutes.settings),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.add_box_outlined),
                  title: const Text('Submit New Product'),
                  onTap: () => context.push(AppRoutes.submitProduct),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.price_change_outlined),
                  title: const Text('Submit Price Update'),
                  onTap: () => context.push(AppRoutes.submitPrice),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () async {
              await ref.read(authSessionProvider.notifier).logout();
              if (context.mounted) {
                context.go(AppRoutes.login);
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
