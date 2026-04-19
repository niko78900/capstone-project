import 'package:cap_app/app/app_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MobileShellScaffold extends StatelessWidget {
  const MobileShellScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        tooltip: 'Contribute',
        onPressed: () => _openContributionActions(context),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomAppBar(
        height: 76,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          children: [
            _ShellNavItem(
              icon: Icons.storefront_outlined,
              label: 'Shop',
              selected: navigationShell.currentIndex == 0,
              onTap: () => _onSelectBranch(context, 0),
            ),
            _ShellNavItem(
              icon: Icons.checklist_outlined,
              label: 'My Items',
              selected: navigationShell.currentIndex == 1,
              onTap: () => _onSelectBranch(context, 1),
            ),
            const SizedBox(width: 64),
            _ShellNavItem(
              icon: Icons.local_grocery_store_outlined,
              label: 'Supermarkets',
              selected: navigationShell.currentIndex == 2,
              onTap: () => _onSelectBranch(context, 2),
            ),
            _ShellNavItem(
              icon: Icons.person_outline,
              label: 'Account',
              selected: navigationShell.currentIndex == 3,
              onTap: () => _onSelectBranch(context, 3),
            ),
          ],
        ),
      ),
    );
  }

  void _onSelectBranch(BuildContext context, int branchIndex) {
    navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }

  Future<void> _openContributionActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (modalContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Submit new product'),
                subtitle: const Text('Propose a product for moderation.'),
                onTap: () {
                  Navigator.of(modalContext).pop();
                  context.push(AppRoutes.submitProduct);
                },
              ),
              ListTile(
                leading: const Icon(Icons.price_change_outlined),
                title: const Text('Submit price update'),
                subtitle: const Text('Send a verified supermarket price.'),
                onTap: () {
                  Navigator.of(modalContext).pop();
                  context.push(AppRoutes.submitPrice);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_a_photo_outlined),
                title: const Text('Upload / attach product image'),
                subtitle: const Text(
                  'Attach image from the product submission form.',
                ),
                onTap: () {
                  Navigator.of(modalContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Open product submission to upload an image.',
                      ),
                    ),
                  );
                  context.push(AppRoutes.submitProduct);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
}

class _ShellNavItem extends StatelessWidget {
  const _ShellNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = selected ? colorScheme.primary : colorScheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
