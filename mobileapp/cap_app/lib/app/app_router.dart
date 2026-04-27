import 'package:cap_app/features/auth/presentation/login_screen.dart';
import 'package:cap_app/features/auth/presentation/register_screen.dart';
import 'package:cap_app/features/auth/providers/auth_providers.dart';
import 'package:cap_app/features/cart/presentation/cart_screen.dart';
import 'package:cap_app/features/cart/models/cart_models.dart';
import 'package:cap_app/features/cart/presentation/compare_result_screen.dart';
import 'package:cap_app/features/cart/presentation/my_items_screen.dart';
import 'package:cap_app/features/catalog/presentation/supermarkets_screen.dart';
import 'package:cap_app/features/catalog/presentation/supermarket_products_screen.dart';
import 'package:cap_app/features/catalog/models/catalog_models.dart';
import 'package:cap_app/features/catalog/presentation/home_screen.dart';
import 'package:cap_app/features/catalog/presentation/product_detail_screen.dart';
import 'package:cap_app/features/account/presentation/account_screen.dart';
import 'package:cap_app/features/settings/presentation/settings_screen.dart';
import 'package:cap_app/features/submissions/presentation/guided_product_submission_screen.dart';
import 'package:cap_app/features/submissions/presentation/my_submissions_screen.dart';
import 'package:cap_app/features/submissions/presentation/submit_price_screen.dart';
import 'package:cap_app/features/submissions/presentation/submit_product_screen.dart';
import 'package:cap_app/app/mobile_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const shop = '/shop';
  static const items = '/items';
  static const supermarkets = '/supermarkets';
  static const supermarketProductsPattern = '/supermarkets/:id/products';
  static const account = '/account';

  // Legacy aliases kept for backward compatibility.
  static const home = '/home';
  static const cart = '/cart';
  static const compareResult = '/compare/result';
  static const submitProduct = '/submit/product';
  static const submitProductGuided = '/submit/product/guided';
  static const submitPrice = '/submit/price';
  static const submissions = '/submissions';
  static const settings = '/settings';

  static String productDetail(int productId) => '/product/$productId';
  static String supermarketProducts(int supermarketId) =>
      '/supermarkets/$supermarketId/products';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authSessionProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    redirect: (context, state) {
      final matchedLocation = state.matchedLocation;
      final session = authState.valueOrNull;
      final isAuthRoute =
          matchedLocation == AppRoutes.login ||
          matchedLocation == AppRoutes.register;

      if (authState.isLoading) {
        return null;
      }

      if (session == null && !isAuthRoute) {
        return AppRoutes.login;
      }

      if (session != null && isAuthRoute) {
        return AppRoutes.shop;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        redirect: (context, state) => AppRoutes.shop,
      ),
      GoRoute(
        path: AppRoutes.cart,
        builder: (context, state) => const CartScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MobileShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.shop,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.items,
                builder: (context, state) => const MyItemsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.supermarkets,
                builder: (context, state) => const SupermarketsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.account,
                builder: (context, state) => const AccountScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) {
            return const _RouteErrorScreen(message: 'Invalid product id');
          }
          return ProductDetailScreen(productId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.supermarketProductsPattern,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) {
            return const _RouteErrorScreen(message: 'Invalid supermarket id');
          }
          final marketName = state.extra is String
              ? state.extra as String
              : null;
          return SupermarketProductsScreen(
            supermarketId: id,
            supermarketName: marketName,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.compareResult,
        builder: (context, state) {
          final result = state.extra is CartComparisonResponse
              ? state.extra as CartComparisonResponse
              : null;
          return CompareResultScreen(result: result);
        },
      ),
      GoRoute(
        path: AppRoutes.submitProduct,
        builder: (context, state) {
          final prefill = state.extra is ProductDetailDto
              ? state.extra as ProductDetailDto
              : null;
          final prefillMap = state.extra is Map
              ? state.extra as Map<Object?, Object?>
              : null;
          final prefillBarcode = prefillMap?['prefillBarcode']?.toString();
          return SubmitProductScreen(
            initialProduct: prefill,
            prefillBarcode: prefillBarcode,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.submitProductGuided,
        builder: (context, state) {
          final prefillMap = state.extra is Map
              ? state.extra as Map<Object?, Object?>
              : null;
          final prefillBarcode = prefillMap?['prefillBarcode']?.toString();
          return GuidedProductSubmissionScreen(prefillBarcode: prefillBarcode);
        },
      ),
      GoRoute(
        path: AppRoutes.submitPrice,
        builder: (context, state) {
          final initialProductId = state.extra is int
              ? state.extra as int
              : null;
          return SubmitPriceScreen(initialProductId: initialProductId);
        },
      ),
      GoRoute(
        path: AppRoutes.submissions,
        builder: (context, state) => const MySubmissionsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});

class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Navigation Error')),
      body: Center(child: Text(message)),
    );
  }
}
