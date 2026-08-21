// File purpose: Defines reusable Flutter widget behavior for android back scope.
import 'package:cap_app/app/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class BackToHomeScope extends StatelessWidget {
  const BackToHomeScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        if (context.mounted) {
          context.go(AppRoutes.home);
        }
      },
      child: child,
    );
  }
}

class HomeExitConfirmScope extends StatefulWidget {
  const HomeExitConfirmScope({required this.child, super.key});

  final Widget child;

  @override
  State<HomeExitConfirmScope> createState() => _HomeExitConfirmScopeState();
}

class _HomeExitConfirmScopeState extends State<HomeExitConfirmScope> {
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
      child: widget.child,
    );
  }
}
