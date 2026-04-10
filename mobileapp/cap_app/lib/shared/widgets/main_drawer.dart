import 'package:cap_app/app/app_router.dart';
import 'package:cap_app/features/auth/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MainDrawer extends ConsumerWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Capstone Supermarket',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (session != null)
                    Text(
                      '${session.user.displayName} • ${session.user.role.name.toUpperCase()}',
                      style: const TextStyle(fontSize: 13),
                    ),
                ],
              ),
            ),
          ),
          _entry(context, icon: Icons.home_outlined, label: 'Home', route: AppRoutes.home),
          _entry(context, icon: Icons.shopping_cart_outlined, label: 'Cart', route: AppRoutes.cart),
          _entry(context, icon: Icons.add_box_outlined, label: 'Submit Product', route: AppRoutes.submitProduct),
          _entry(context, icon: Icons.price_change_outlined, label: 'Submit Price', route: AppRoutes.submitPrice),
          _entry(context, icon: Icons.inbox_outlined, label: 'My Submissions', route: AppRoutes.submissions),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await ref.read(authSessionProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(context).pop();
                context.go(AppRoutes.login);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _entry(BuildContext context, {required IconData icon, required String label, required String route}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        Navigator.of(context).pop();
        context.go(route);
      },
    );
  }
}
