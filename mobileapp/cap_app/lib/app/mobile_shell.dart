import 'package:cap_app/app/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class MobileShellScaffold extends StatefulWidget {
  const MobileShellScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  State<MobileShellScaffold> createState() => _MobileShellScaffoldState();
}

class _MobileShellScaffoldState extends State<MobileShellScaffold> {
  bool _dialogVisible = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _dialogVisible) {
          return;
        }
        _dialogVisible = true;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Exit app?'),
              content: const Text('Do you want to close the app?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Exit'),
                ),
              ],
            );
          },
        );
        _dialogVisible = false;
        if (!mounted) {
          return;
        }
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: widget.navigationShell,
        bottomNavigationBar: BottomAppBar(
          height: 76,
          child: Row(
            children: [
              _ShellNavItem(
                icon: Icons.storefront_outlined,
                label: 'Shop',
                selected: widget.navigationShell.currentIndex == 0,
                onTap: () => _onSelectBranch(0),
              ),
              _ShellNavItem(
                icon: Icons.checklist_outlined,
                label: 'My Items',
                selected: widget.navigationShell.currentIndex == 1,
                onTap: () => _onSelectBranch(1),
              ),
              _ShellActionItem(
                icon: Icons.add,
                label: 'Add',
                onTap: () => _openContributionActions(context),
              ),
              _ShellNavItem(
                icon: Icons.local_grocery_store_outlined,
                label: 'Markets',
                selected: widget.navigationShell.currentIndex == 2,
                onTap: () => _onSelectBranch(2),
              ),
              _ShellNavItem(
                icon: Icons.person_outline,
                label: 'Account',
                selected: widget.navigationShell.currentIndex == 3,
                onTap: () => _onSelectBranch(3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onSelectBranch(int branchIndex) {
    widget.navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == widget.navigationShell.currentIndex,
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

class _ShellActionItem extends StatelessWidget {
  const _ShellActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
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
