import 'package:cap_app/app/app_router.dart';
import 'package:cap_app/core/network/auth_token_storage.dart';
import 'package:cap_app/core/network/network_providers.dart';
import 'package:cap_app/features/auth/models/auth_models.dart';
import 'package:cap_app/features/auth/presentation/login_screen.dart';
import 'package:cap_app/features/auth/presentation/register_screen.dart';
import 'package:cap_app/features/auth/providers/auth_providers.dart';
import 'package:cap_app/features/cart/models/cart_models.dart';
import 'package:cap_app/features/cart/providers/cart_providers.dart';
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
            authTokenStorageProvider.overrideWithValue(_FakeAuthTokenStorage()),
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

    testWidgets('login remembers saved credentials and checks remember me', (
      tester,
    ) async {
      final storage = _FakeAuthTokenStorage(
        remembered: const RememberedCredentials(
          email: 'saved@example.com',
          password: 'Password123!',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(_FakeAuthSessionController.new),
            authTokenStorageProvider.overrideWithValue(storage),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Remember me?'), findsOneWidget);

      final emailField = tester.widget<TextFormField>(
        find.byType(TextFormField).at(0),
      );
      final passwordField = tester.widget<TextFormField>(
        find.byType(TextFormField).at(1),
      );
      final rememberTile = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );

      expect(emailField.controller?.text, 'saved@example.com');
      expect(passwordField.controller?.text, 'Password123!');
      expect(rememberTile.value, isTrue);
    });

    testWidgets('unchecked remember me clears saved credentials on login', (
      tester,
    ) async {
      final storage = _FakeAuthTokenStorage(
        remembered: const RememberedCredentials(
          email: 'saved@example.com',
          password: 'Password123!',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(_FakeAuthSessionController.new),
            authTokenStorageProvider.overrideWithValue(storage),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      expect(storage.clearedRemembered, isTrue);
      expect(storage.remembered, isNull);
    });

    testWidgets('register validates password confirmation mismatch', (
      tester,
    ) async {
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
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'niko@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      await tester.enterText(find.byType(TextFormField).at(3), 'different123');
      await tester.tap(find.text('Register'));
      await tester.pump();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });
  });

  testWidgets('mobile shell bottom navigation uses Markets label', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(_LoggedInAuthSessionController.new),
          authTokenStorageProvider.overrideWithValue(_FakeAuthTokenStorage()),
          productListProvider.overrideWith((ref) async => const []),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            final router = ref.watch(appRouterProvider);
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Markets'), findsOneWidget);
    expect(find.text('Supermarkets'), findsNothing);
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

    expect(find.text('Milk 1L'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Tinex'), findsAtLeastNWidgets(1));
  });

  testWidgets('root tabs back press opens exit confirmation dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(_LoggedInAuthSessionController.new),
          authTokenStorageProvider.overrideWithValue(_FakeAuthTokenStorage()),
          productListProvider.overrideWith((ref) async => const []),
          recentCartItemsProvider.overrideWith(
            _FakeRecentCartItemsNotifier.new,
          ),
          supermarketsProvider.overrideWith(
            (ref) async => const <SupermarketDto>[],
          ),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            final router = ref.watch(appRouterProvider);
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> expectExitDialogThenCancel() async {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Exit app?'), findsOneWidget);
      expect(find.text('Do you want to close the app?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    }

    await expectExitDialogThenCancel();

    await tester.tap(find.byIcon(Icons.checklist_outlined));
    await tester.pumpAndSettle();
    await expectExitDialogThenCancel();

    await tester.tap(find.byIcon(Icons.local_grocery_store_outlined));
    await tester.pumpAndSettle();
    await expectExitDialogThenCancel();

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    await expectExitDialogThenCancel();
  });
}

class _FakeAuthSessionController extends AuthSessionController {
  @override
  Future<AuthSession?> build() async => null;

  @override
  Future<void> login({required String email, required String password}) async {
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

class _LoggedInAuthSessionController extends AuthSessionController {
  @override
  Future<AuthSession?> build() async => _demoSession;

  @override
  Future<void> login({required String email, required String password}) async {
    state = const AsyncData(_demoSession);
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AsyncData(_demoSession);
  }

  @override
  Future<void> logout() async {
    state = const AsyncData(null);
  }
}

class _FakeRecentCartItemsNotifier extends RecentCartItemsNotifier {
  @override
  Future<List<RecentCartItem>> build() async => const [];
}

class _FakeAuthTokenStorage extends AuthTokenStorage {
  _FakeAuthTokenStorage({this.remembered});

  String? _token;
  RememberedCredentials? remembered;
  bool clearedRemembered = false;

  @override
  Future<void> saveToken(String token) async {
    _token = token;
  }

  @override
  Future<String?> readToken() async {
    return _token;
  }

  @override
  Future<void> clearToken() async {
    _token = null;
  }

  @override
  Future<void> saveRememberedCredentials({
    required String email,
    required String password,
  }) async {
    remembered = RememberedCredentials(email: email, password: password);
  }

  @override
  Future<RememberedCredentials?> readRememberedCredentials() async {
    return remembered;
  }

  @override
  Future<void> clearRememberedCredentials() async {
    remembered = null;
    clearedRemembered = true;
  }
}

const _demoSession = AuthSession(
  accessToken: 'token',
  tokenType: 'Bearer',
  expiresInMs: 604800000,
  user: AuthUser(
    id: 1,
    email: 'tester@example.com',
    displayName: 'Tester',
    role: UserRole.user,
  ),
);
