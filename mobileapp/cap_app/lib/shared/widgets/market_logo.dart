import 'package:flutter/material.dart';

class MarketLogo extends StatelessWidget {
  const MarketLogo({
    required this.supermarketName,
    this.width = 44,
    this.height = 44,
    super.key,
  });

  final String supermarketName;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final config = _marketLogosByName[_normalizeMarketName(supermarketName)];
    final theme = Theme.of(context);
    final backgroundColor = config?.darkTile == true
        ? const Color(0xFF0F1713)
        : theme.colorScheme.surfaceContainerHighest;

    return Semantics(
      label: '$supermarketName logo',
      image: config != null,
      child: Container(
        width: width,
        height: height,
        padding: EdgeInsets.all(config?.padding ?? 5),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: config == null
            ? _MarketLogoFallback(supermarketName: supermarketName)
            : Image.asset(
                config.assetPath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    _MarketLogoFallback(supermarketName: supermarketName),
              ),
      ),
    );
  }
}

class _MarketLogoFallback extends StatelessWidget {
  const _MarketLogoFallback({required this.supermarketName});

  final String supermarketName;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storefront_outlined, size: 18, color: color),
          Text(
            _initials(supermarketName),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketLogoAsset {
  const _MarketLogoAsset(this.assetPath, {this.darkTile = false, this.padding});

  final String assetPath;
  final bool darkTile;
  final double? padding;
}

const _marketLogosByName = {
  'tinex': _MarketLogoAsset('assets/market_logos/tinex.png'),
  'vero': _MarketLogoAsset('assets/market_logos/vero.png'),
  'kam market': _MarketLogoAsset('assets/market_logos/kam.png'),
  'ramstore': _MarketLogoAsset('assets/market_logos/ramstore.png'),
  'stokomak': _MarketLogoAsset(
    'assets/market_logos/stokomak.png',
    darkTile: true,
    padding: 6,
  ),
  'kit-go market': _MarketLogoAsset('assets/market_logos/kit-go.png'),
  'kipper': _MarketLogoAsset('assets/market_logos/kipper.png'),
  'zur': _MarketLogoAsset('assets/market_logos/zur.png'),
  'reptil': _MarketLogoAsset('assets/market_logos/reptil.png'),
  'zhito': _MarketLogoAsset('assets/market_logos/zhito.png'),
  'zhito marketi': _MarketLogoAsset('assets/market_logos/zhito.png'),
};

String _normalizeMarketName(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

String _initials(String value) {
  final tokens = _normalizeMarketName(value).split(' ').where((part) {
    return part.isNotEmpty;
  }).toList();
  final initials = tokens.take(2).map((token) => token[0]).join().toUpperCase();
  return initials.isEmpty ? '?' : initials;
}
