import 'package:cap_app/features/cart/models/cart_models.dart';
import 'package:cap_app/features/cart/providers/cart_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('add, update, remove, and persist cart items', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(cartNotifierProvider.future);
    final notifier = container.read(cartNotifierProvider.notifier);

    await notifier.addOrIncrement(productId: 1, productName: 'Banana');
    await notifier.addOrIncrement(productId: 1, productName: 'Banana');

    var items = container.read(cartNotifierProvider).valueOrNull ?? const <CartItem>[];
    expect(items, hasLength(1));
    expect(items.first.quantity, 2);

    await notifier.updateQuantity(productId: 1, quantity: 3.5);
    items = container.read(cartNotifierProvider).valueOrNull ?? const <CartItem>[];
    expect(items.first.quantity, 3.5);

    await notifier.decrement(1);
    items = container.read(cartNotifierProvider).valueOrNull ?? const <CartItem>[];
    expect(items.first.quantity, 2.5);

    await notifier.remove(1);
    items = container.read(cartNotifierProvider).valueOrNull ?? const <CartItem>[];
    expect(items, isEmpty);

    await notifier.addOrIncrement(productId: 2, productName: 'Milk');
    final container2 = ProviderContainer();
    addTearDown(container2.dispose);
    final restored = await container2.read(cartNotifierProvider.future);
    expect(restored, hasLength(1));
    expect(restored.first.productName, 'Milk');
  });
}
