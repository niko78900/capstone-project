import 'package:cap_app/features/auth/models/auth_models.dart';
import 'package:cap_app/features/auth/presentation/login_screen.dart';
import 'package:cap_app/features/auth/presentation/register_screen.dart';
import 'package:cap_app/features/auth/providers/auth_providers.dart';
import 'package:cap_app/features/catalog/models/catalog_models.dart';
import 'package:cap_app/features/catalog/presentation/home_screen.dart';
import 'package:cap_app/features/catalog/providers/catalog_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Auth screens', () {
    testWidgets('login validates required email and password', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(_FakeAuthSessionController.new),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Login'));
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('register validates password confirmation mismatch', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(_FakeAuthSessionController.new),
          ],
          child: const MaterialApp(home: RegisterScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Niko');
      await tester.enterText(find.byType(TextFormField).at(1), 'niko@example.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      await tester.enterText(find.byType(TextFormField).at(3), 'different123');
      await tester.tap(find.text('Register'));
      await tester.pump();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });
  });

  testWidgets('home screen renders products from provider', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(_FakeAuthSessionController.new),
          productListProvider.overrideWith(
            (ref) async => const [
              ProductSummaryDto(
                id: 1,
                name: 'Milk 1L',
                brand: 'Bucen Kozjak',
                barcode: '123',
                category: 'Dairy & Eggs',
                bestPrice: 62.0,
                bestPriceSupermarket: 'Tinex',
                currency: 'MKD',
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Milk 1L'), findsOneWidget);
    expect(find.textContaining('Dairy & Eggs'), findsOneWidget);
  });
}

class _FakeAuthSessionController extends AuthSessionController {
  @override
  Future<AuthSession?> build() async => null;

  @override
  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncData(null);
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AsyncData(null);
  }

  @override
  Future<void> logout() async {
    state = const AsyncData(null);
  }
}
