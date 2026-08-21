// File purpose: Defines reusable Flutter widget behavior for my items icon button.
import 'package:cap_app/app/app_router.dart';
import 'package:cap_app/features/cart/providers/cart_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MyItemsIconButton extends ConsumerWidget {
  const MyItemsIconButton({this.tooltip = 'Cart', this.onPressed, super.key});

  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsCount = ref.watch(
      cartNotifierProvider.select((state) {
        return state.maybeWhen(
          data: (items) =>
              items.fold<int>(0, (sum, item) => sum + item.quantity.round()),
          orElse: () => 0,
        );
      }),
    );

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed ?? () => context.push(AppRoutes.cart),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.shopping_basket_outlined),
          if (itemsCount > 0)
            Positioned(right: -7, top: -5, child: _Badge(count: itemsCount)),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final display = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.error,
        borderRadius: BorderRadius.circular(999),
      ),
      constraints: const BoxConstraints(minWidth: 18),
      child: Text(
        display,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colorScheme.onError,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}
