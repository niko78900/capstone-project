import 'package:cap_app/app/app_router.dart';
import 'package:cap_app/core/notifications/local_notifications_service.dart';
import 'package:cap_app/core/network/auth_token_storage.dart';
import 'package:cap_app/core/network/api_client.dart';
import 'package:cap_app/core/network/network_providers.dart';
import 'package:cap_app/features/auth/models/auth_models.dart';
import 'package:cap_app/features/auth/models/password_reset_models.dart';
import 'package:cap_app/features/auth/data/password_reset_repository.dart';
import 'package:cap_app/features/auth/presentation/forgot_password_screen.dart';
import 'package:cap_app/features/auth/presentation/login_screen.dart';
import 'package:cap_app/features/auth/presentation/register_screen.dart';
import 'package:cap_app/features/auth/presentation/reset_password_screen.dart';
import 'package:cap_app/features/auth/providers/auth_providers.dart';
import 'package:cap_app/features/cart/models/cart_models.dart';
import 'package:cap_app/features/cart/presentation/compare_result_screen.dart';
import 'package:cap_app/features/cart/providers/cart_providers.dart';
import 'package:cap_app/features/catalog/models/catalog_models.dart';
import 'package:cap_app/features/catalog/presentation/home_screen.dart';
import 'package:cap_app/features/catalog/presentation/product_detail_screen.dart';
import 'package:cap_app/features/catalog/providers/catalog_providers.dart';
import 'package:cap_app/shared/widgets/market_logo.dart';
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
      expect(find.text('Forgot password?'), findsOneWidget);
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

    testWidgets('forgot password submits reset request', (tester) async {
      final resetRepository = _FakePasswordResetRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            passwordResetRepositoryProvider.overrideWithValue(resetRepository),
          ],
          child: const MaterialApp(home: ForgotPasswordScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'reset@example.com');
      await tester.tap(find.text('Request reset'));
      await tester.pumpAndSettle();

      expect(resetRepository.requestedEmail, 'reset@example.com');
      expect(find.textContaining('Request sent'), findsOneWidget);
    });

    testWidgets('reset password validates confirmation mismatch', (
      tester,
    ) async {
      final resetRepository = _FakePasswordResetRepository(
        storedStatus: const PasswordResetStatusResponse(
          status: PasswordResetStatus.approved,
          email: 'approved@example.com',
          expiresAt: null,
          updatedAt: null,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            passwordResetRepositoryProvider.overrideWithValue(resetRepository),
          ],
          child: const MaterialApp(home: ResetPasswordScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(1), 'Password123!');
      await tester.enterText(find.byType(TextFormField).at(2), 'Different123!');
      await tester.tap(find.text('Set new password'));
      await tester.pump();

      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(resetRepository.completedEmail, isNull);
    });

    testWidgets('approved stored reset routes authenticated users to reset', (
      tester,
    ) async {
      final resetRepository = _FakePasswordResetRepository(
        storedStatus: const PasswordResetStatusResponse(
          status: PasswordResetStatus.approved,
          email: 'approved@example.com',
          expiresAt: null,
          updatedAt: null,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(
              _LoggedInAuthSessionController.new,
            ),
            passwordResetRepositoryProvider.overrideWithValue(resetRepository),
            localNotificationsServiceProvider.overrideWithValue(
              _FakeLocalNotificationsService(),
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

      expect(find.text('Set a new password'), findsOneWidget);
      expect(find.text('Welcome Back'), findsNothing);
    });

    test('denied stored reset clears token through the shared gate', () async {
      final resetRepository = _FakePasswordResetRepository(
        storedStatus: const PasswordResetStatusResponse(
          status: PasswordResetStatus.denied,
          email: 'denied@example.com',
          expiresAt: null,
          updatedAt: null,
        ),
      );
      final notifications = _FakeLocalNotificationsService();
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(_LoggedInAuthSessionController.new),
          passwordResetRepositoryProvider.overrideWithValue(resetRepository),
          localNotificationsServiceProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(container.dispose);

      final status = await container.read(passwordResetGateProvider.future);

      expect(status, isNull);
      expect(resetRepository.storedStatus, isNull);
      expect(notifications.shownIds, contains(310002));
    });

    for (final status in [
      PasswordResetStatus.completed,
      PasswordResetStatus.expired,
    ]) {
      test(
        '$status stored reset clears token through the shared gate',
        () async {
          final resetRepository = _FakePasswordResetRepository(
            storedStatus: PasswordResetStatusResponse(
              status: status,
              email: 'terminal@example.com',
              expiresAt: null,
              updatedAt: null,
            ),
          );
          final notifications = _FakeLocalNotificationsService();
          final container = ProviderContainer(
            overrides: [
              authSessionProvider.overrideWith(
                _LoggedInAuthSessionController.new,
              ),
              passwordResetRepositoryProvider.overrideWithValue(
                resetRepository,
              ),
              localNotificationsServiceProvider.overrideWithValue(
                notifications,
              ),
            ],
          );
          addTearDown(container.dispose);

          final gateStatus = await container.read(
            passwordResetGateProvider.future,
          );

          expect(gateStatus, isNull);
          expect(resetRepository.storedStatus, isNull);
          expect(notifications.shownIds, isEmpty);
        },
      );
    }
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

  testWidgets('add action exposes the three submission choices', (
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
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Submit a product manually'), findsOneWidget);
    expect(find.text('Submit a product guided'), findsOneWidget);
    expect(find.text('Submit a price update'), findsOneWidget);
    expect(find.text('Upload / attach product image'), findsNothing);
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
    expect(find.byType(MarketLogo), findsAtLeastNWidgets(1));
  });

  testWidgets('product detail shows price history below verified prices', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productDetailProvider(1).overrideWith(
            (ref) async => ProductDetailDto(
              id: 1,
              name: 'Milk 1L',
              brand: 'Bucen Kozjak',
              barcode: '123',
              category: 'Dairy & Eggs',
              nutrition: null,
              prices: [
                ProductPriceDto(
                  supermarketId: 1,
                  supermarketName: 'Tinex',
                  price: 62,
                  currency: 'MKD',
                  observedAt: DateTime.utc(2026, 4, 12),
                ),
              ],
              priceHistory: [
                ProductPriceHistoryPointDto(
                  supermarketId: 1,
                  supermarketName: 'Tinex',
                  price: 65,
                  currency: 'MKD',
                  observedAt: DateTime.utc(2026, 3, 12),
                ),
                ProductPriceHistoryPointDto(
                  supermarketId: 1,
                  supermarketName: 'Tinex',
                  price: 62,
                  currency: 'MKD',
                  observedAt: DateTime.utc(2026, 4, 12),
                ),
                ProductPriceHistoryPointDto(
                  supermarketId: 2,
                  supermarketName: 'Vero',
                  price: 69,
                  currency: 'MKD',
                  observedAt: DateTime.utc(2026, 4, 10),
                ),
              ],
            ),
          ),
          cartNotifierProvider.overrideWith(_FakeCartNotifier.new),
        ],
        child: const MaterialApp(home: ProductDetailScreen(productId: 1)),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Verified Prices'), findsOneWidget);
    expect(find.text('Price History'), findsOneWidget);
    expect(find.text('Vero'), findsOneWidget);
    expect(find.textContaining('latest'), findsWidgets);
    expect(find.byType(MarketLogo), findsAtLeastNWidgets(2));
  });

  testWidgets(
    'cart comparison renders market logos for cheapest and ranked rows',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CompareResultScreen(
              result: CartComparisonResponse(
                requestItemCount: 2,
                cheapestEligible: CheapestEligibleOptionDto(
                  supermarketId: 1,
                  supermarketName: 'Tinex',
                  totalCost: 180,
                  currency: 'MKD',
                ),
                rankedSupermarkets: [
                  SupermarketCartResultDto(
                    supermarketId: 1,
                    supermarketName: 'Tinex',
                    totalCost: 180,
                    currency: 'MKD',
                    fullCoverage: true,
                    coverageRatio: 1,
                    missingItems: [],
                    lineItems: [
                      CartLineItemDto(
                        productId: 1,
                        productName: 'Milk 1L',
                        quantity: 1,
                        unitPrice: 70,
                        lineTotal: 70,
                      ),
                    ],
                  ),
                  SupermarketCartResultDto(
                    supermarketId: 2,
                    supermarketName: 'Vero',
                    totalCost: 95,
                    currency: 'MKD',
                    fullCoverage: false,
                    coverageRatio: 0.5,
                    missingItems: [
                      MissingCartItemDto(productId: 2, productName: 'Bread'),
                    ],
                    lineItems: [
                      CartLineItemDto(
                        productId: 1,
                        productName: 'Milk 1L',
                        quantity: 1,
                        unitPrice: 95,
                        lineTotal: 95,
                      ),
                    ],
                  ),
                ],
                diagnostics: CartDiagnosticsDto(
                  eligibleSupermarkets: 1,
                  partialSupermarkets: 1,
                  totalSupermarkets: 2,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Cheapest eligible option'), findsOneWidget);
      expect(find.text('Ranked supermarkets'), findsOneWidget);
      expect(find.byType(MarketLogo), findsNWidgets(3));

      final assetNames = tester
          .widgetList<Image>(find.byType(Image))
          .map((image) => (image.image as AssetImage).assetName)
          .toList();
      expect(assetNames, contains('assets/market_logos/tinex.png'));
      expect(assetNames, contains('assets/market_logos/vero.png'));
    },
  );

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

class _FakeCartNotifier extends CartNotifier {
  @override
  Future<List<CartItem>> build() async => const [];
}

class _FakeAuthTokenStorage extends AuthTokenStorage {
  _FakeAuthTokenStorage({this.remembered});

  String? _token;
  RememberedCredentials? remembered;
  String? passwordResetToken;
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

  @override
  Future<void> savePasswordResetToken(String token) async {
    passwordResetToken = token;
  }

  @override
  Future<String?> readPasswordResetToken() async {
    return passwordResetToken;
  }

  @override
  Future<void> clearPasswordResetToken() async {
    passwordResetToken = null;
  }
}

class _FakePasswordResetRepository extends PasswordResetRepository {
  _FakePasswordResetRepository({this.storedStatus})
    : super(ApiClient(_FakeAuthTokenStorage()), _FakeAuthTokenStorage());

  PasswordResetStatusResponse? storedStatus;
  String? requestedEmail;
  String? completedEmail;

  @override
  Future<PasswordResetRequestResponse> requestReset(String email) async {
    requestedEmail = email;
    return PasswordResetRequestResponse(
      requestToken: 'reset-token',
      status: PasswordResetStatus.pending,
      expiresAt: DateTime.utc(2026, 5, 14),
    );
  }

  @override
  Future<PasswordResetStatusResponse?> checkStoredStatus() async {
    return storedStatus;
  }

  @override
  Future<PasswordResetCompleteResponse> completeStoredReset({
    required String email,
    required String newPassword,
  }) async {
    completedEmail = email;
    return const PasswordResetCompleteResponse(
      status: PasswordResetStatus.completed,
      message: 'Password reset completed',
    );
  }

  @override
  Future<void> clearStoredRequest() async {
    storedStatus = null;
  }
}

class _FakeLocalNotificationsService extends LocalNotificationsService {
  final shownIds = <int>[];

  @override
  Future<void> ensureInitialized() async {}

  @override
  Future<void> show({
    required int notificationId,
    required String title,
    required String body,
  }) async {
    shownIds.add(notificationId);
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
