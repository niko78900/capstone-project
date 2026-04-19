import 'package:cap_app/core/network/network_providers.dart';
import 'package:cap_app/features/auth/providers/auth_providers.dart';
import 'package:cap_app/features/cart/data/cart_repository.dart';
import 'package:cap_app/features/cart/models/cart_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.read(apiClientProvider));
});

final recentCartItemsProvider =
    AsyncNotifierProvider<RecentCartItemsNotifier, List<RecentCartItem>>(
      RecentCartItemsNotifier.new,
    );

class RecentCartItemsNotifier extends AsyncNotifier<List<RecentCartItem>> {
  static const _storageKey = 'recent_cart_items';
  static const _maxItems = 60;

  @override
  Future<List<RecentCartItem>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final decoded = RecentCartItem.decodeList(prefs.getString(_storageKey));
    decoded.sort((a, b) => b.lastAddedAt.compareTo(a.lastAddedAt));
    return decoded.take(_maxItems).toList();
  }

  Future<void> recordAdd({
    required int productId,
    required String productName,
  }) async {
    final now = DateTime.now().toUtc();
    final items = [...(state.valueOrNull ?? const <RecentCartItem>[])];
    final existingIndex = items.indexWhere(
      (item) => item.productId == productId,
    );
    if (existingIndex >= 0) {
      final existing = items[existingIndex];
      items[existingIndex] = existing.copyWith(
        productName: productName,
        lastAddedAt: now,
        addCount: existing.addCount + 1,
      );
    } else {
      items.add(
        RecentCartItem(
          productId: productId,
          productName: productName,
          lastAddedAt: now,
          addCount: 1,
        ),
      );
    }
    items.sort((a, b) => b.lastAddedAt.compareTo(a.lastAddedAt));
    await _setAndPersist(items.take(_maxItems).toList());
  }

  Future<void> removeFromHistory(int productId) async {
    final items = [...(state.valueOrNull ?? const <RecentCartItem>[])];
    items.removeWhere((item) => item.productId == productId);
    await _setAndPersist(items);
  }

  Future<void> clearHistory() async {
    await _setAndPersist(const []);
  }

  Future<void> _setAndPersist(List<RecentCartItem> items) async {
    state = AsyncData(items);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, RecentCartItem.encodeList(items));
  }
}

final cartNotifierProvider =
    AsyncNotifierProvider<CartNotifier, List<CartItem>>(CartNotifier.new);

class CartNotifier extends AsyncNotifier<List<CartItem>> {
  static const _storageKey = 'local_cart_items';

  @override
  Future<List<CartItem>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return CartItem.decodeList(prefs.getString(_storageKey));
  }

  Future<void> addOrIncrement({
    required int productId,
    required String productName,
  }) async {
    final items = [...(state.valueOrNull ?? const <CartItem>[])];
    final existingIndex = items.indexWhere(
      (item) => item.productId == productId,
    );
    if (existingIndex >= 0) {
      final existing = items[existingIndex];
      items[existingIndex] = existing.copyWith(quantity: existing.quantity + 1);
    } else {
      items.add(
        CartItem(productId: productId, productName: productName, quantity: 1),
      );
    }
    await _setAndPersist(items);
    await ref
        .read(recentCartItemsProvider.notifier)
        .recordAdd(productId: productId, productName: productName);
  }

  Future<void> updateQuantity({
    required int productId,
    required double quantity,
  }) async {
    final safeQuantity = quantity < 0.01 ? 0.01 : quantity;
    final items = [...(state.valueOrNull ?? const <CartItem>[])];
    final existingIndex = items.indexWhere(
      (item) => item.productId == productId,
    );
    if (existingIndex < 0) {
      return;
    }
    final existing = items[existingIndex];
    items[existingIndex] = existing.copyWith(quantity: safeQuantity);
    await _setAndPersist(items);
  }

  Future<void> decrement(int productId) async {
    final items = [...(state.valueOrNull ?? const <CartItem>[])];
    final existingIndex = items.indexWhere(
      (item) => item.productId == productId,
    );
    if (existingIndex < 0) {
      return;
    }
    final existing = items[existingIndex];
    final nextQuantity = existing.quantity - 1;
    if (nextQuantity <= 0) {
      items.removeAt(existingIndex);
    } else {
      items[existingIndex] = existing.copyWith(quantity: nextQuantity);
    }
    await _setAndPersist(items);
  }

  Future<void> remove(int productId) async {
    final items = [...(state.valueOrNull ?? const <CartItem>[])];
    items.removeWhere((item) => item.productId == productId);
    await _setAndPersist(items);
  }

  Future<void> clear() async {
    await _setAndPersist(const []);
  }

  Future<void> _setAndPersist(List<CartItem> items) async {
    state = AsyncData(items);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, CartItem.encodeList(items));
  }
}

final cartComparisonControllerProvider =
    AutoDisposeAsyncNotifierProvider<
      CartComparisonController,
      CartComparisonResponse?
    >(CartComparisonController.new);

class CartComparisonController
    extends AutoDisposeAsyncNotifier<CartComparisonResponse?> {
  CartRepository get _repo => ref.read(cartRepositoryProvider);

  @override
  Future<CartComparisonResponse?> build() async {
    return null;
  }

  Future<CartComparisonResponse?> compare(List<CartItem> items) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final response = await _repo.compareSingleSupermarket(
        items
            .map(
              (item) => CartCompareItemRequest(
                productId: item.productId,
                quantity: item.quantity,
              ),
            )
            .toList(),
      );
      return response;
    });
    final error = state.asError?.error;
    if (error != null) {
      await ref
          .read(authSessionProvider.notifier)
          .forceLogoutOnUnauthorized(error);
      return null;
    }
    return state.valueOrNull;
  }

  void clearResult() {
    state = const AsyncData(null);
  }
}
