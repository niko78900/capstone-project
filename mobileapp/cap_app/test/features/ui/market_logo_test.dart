import 'package:cap_app/shared/widgets/market_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MarketLogo renders known market asset by normalized name', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MarketLogo(supermarketName: '  KAM   Market ')),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as AssetImage;
    expect(provider.assetName, 'assets/market_logos/kam.png');
  });

  testWidgets('MarketLogo renders fallback for unknown market', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MarketLogo(supermarketName: 'Corner Market')),
      ),
    );

    expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
    expect(find.text('CM'), findsOneWidget);
  });
}
