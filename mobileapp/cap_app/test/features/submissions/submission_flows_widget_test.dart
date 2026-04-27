import 'package:cap_app/core/network/api_client.dart';
import 'package:cap_app/core/network/auth_token_storage.dart';
import 'package:cap_app/features/catalog/data/catalog_repository.dart';
import 'package:cap_app/features/catalog/models/catalog_models.dart';
import 'package:cap_app/features/catalog/providers/catalog_providers.dart';
import 'package:cap_app/features/settings/providers/settings_providers.dart';
import 'package:cap_app/features/submissions/presentation/guided_product_submission_screen.dart';
import 'package:cap_app/features/submissions/presentation/submit_price_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('guided submission blocks duplicate barcode creation', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          debugModeEnabledProvider.overrideWithValue(false),
          catalogRepositoryProvider.overrideWithValue(
            _FakeCatalogRepository(
              products: const [
                ProductSummaryDto(
                  id: 7,
                  name: 'Milk 1L',
                  brand: 'Bitolsko',
                  barcode: '12345',
                  category: 'Dairy & Eggs',
                ),
              ],
            ),
          ),
        ],
        child: const MaterialApp(
          home: GuidedProductSubmissionScreen(prefillBarcode: '12345'),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('Product already exists'), findsOneWidget);
    expect(find.textContaining('Milk 1L'), findsOneWidget);
    expect(find.text('Submit price update'), findsOneWidget);
  });

  testWidgets('price update shows not-found actions for unknown barcode', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          debugModeEnabledProvider.overrideWithValue(false),
          catalogRepositoryProvider.overrideWithValue(
            _FakeCatalogRepository(products: const []),
          ),
        ],
        child: const MaterialApp(home: SubmitPriceScreen()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '99999');
    await tester.tap(find.text('Search barcode'));
    await tester.pumpAndSettle();

    expect(find.text('Product not found'), findsOneWidget);
    expect(find.text('Submit product guided'), findsOneWidget);
    expect(find.text('Submit product manually'), findsOneWidget);
    expect(find.text('Scan again'), findsOneWidget);
  });

  testWidgets('price update confirms found barcode before price form', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          debugModeEnabledProvider.overrideWithValue(false),
          catalogRepositoryProvider.overrideWithValue(
            _FakeCatalogRepository(
              products: const [
                ProductSummaryDto(
                  id: 12,
                  name: 'Cola 2L',
                  brand: 'Skopsko',
                  barcode: '55555',
                  category: 'Beverages',
                ),
              ],
            ),
          ),
          supermarketsProvider.overrideWith(
            (ref) async => const [SupermarketDto(id: 1, name: 'Zur')],
          ),
        ],
        child: const MaterialApp(home: SubmitPriceScreen()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '55555');
    await tester.tap(find.text('Search barcode'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm the matched product.'), findsOneWidget);
    expect(find.text('Cola 2L'), findsOneWidget);

    await tester.tap(find.text('This is the product'));
    await tester.pumpAndSettle();

    expect(find.text('Market'), findsOneWidget);
    expect(find.text('Price (MKD)'), findsOneWidget);
    expect(find.text('Submit price update'), findsOneWidget);
  });
}

class _FakeCatalogRepository extends CatalogRepository {
  _FakeCatalogRepository({required this.products})
    : super(ApiClient(const AuthTokenStorage()));

  final List<ProductSummaryDto> products;

  @override
  Future<List<ProductSummaryDto>> getProducts({
    String? query,
    int? supermarketId,
  }) async {
    return products;
  }
}
