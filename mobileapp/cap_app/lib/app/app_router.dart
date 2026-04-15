import 'package:cap_app/features/auth/models/auth_models.dart';
import 'package:cap_app/features/auth/presentation/login_screen.dart';
import 'package:cap_app/features/auth/presentation/register_screen.dart';
import 'package:cap_app/features/auth/providers/auth_providers.dart';
import 'package:cap_app/features/cart/models/cart_models.dart';
import 'package:cap_app/features/cart/presentation/cart_screen.dart';
import 'package:cap_app/features/cart/presentation/compare_result_screen.dart';
import 'package:cap_app/features/catalog/models/catalog_models.dart';
import 'package:cap_app/features/catalog/presentation/home_screen.dart';
import 'package:cap_app/features/catalog/presentation/product_detail_screen.dart';
import 'package:cap_app/features/submissions/presentation/my_submissions_screen.dart';
import 'package:cap_app/features/submissions/presentation/submit_price_screen.dart';
import 'package:cap_app/features/submissions/presentation/submit_product_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const cart = '/cart';
  static const compareResult = '/compare/result';
  static const submitProduct = '/submit/product';
  static const submitPrice = '/submit/price';
  static const submissions = '/submissions';

  static String productDetail(int productId) => '/product/$productId';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ValueNotifier<int>(0);
  ref.onDispose(refreshListenable.dispose);
  ref.listen<AsyncValue<AuthSession?>>(
    authSessionProvider,
    (previous, next) => refreshListenable.value++,
  );

  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authSessionProvider);
      final session = authState.valueOrNull;
      final isAuthRoute =
          state.fullPath == AppRoutes.login ||
          state.fullPath == AppRoutes.register;

      if (authState.isLoading) {
        return null;
      }

      if (session == null && !isAuthRoute) {
        return AppRoutes.login;
      }

      if (session != null && isAuthRoute) {
        return AppRoutes.home;
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
        builder: (context, state) => const HomeScreen(),
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
        path: AppRoutes.cart,
        builder: (context, state) => const CartScreen(),
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
          return SubmitProductScreen(initialProduct: prefill);
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
