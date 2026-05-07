import 'dart:math' as math;

import 'package:cap_app/core/utils/formatters.dart';
import 'package:cap_app/features/catalog/models/catalog_models.dart';
import 'package:flutter/material.dart';

class PriceHistoryChart extends StatelessWidget {
  const PriceHistoryChart({required this.points, super.key});

  final List<ProductPriceHistoryPointDto> points;

  @override
  Widget build(BuildContext context) {
    final series = _buildSeries(points);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Price History', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Verified prices over time by market.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (series.isEmpty)
              const Text('No price history is available for this product.')
            else ...[
              SizedBox(
                height: 220,
                width: double.infinity,
                child: CustomPaint(
                  painter: _PriceHistoryChartPainter(
                    series: series,
                    colorScheme: theme.colorScheme,
                    textStyle: theme.textTheme.labelSmall,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (final item in series)
                    _LegendItem(
                      color: item.color,
                      label: item.supermarketName,
                      latestPrice: item.latest.price,
                      currency: item.latest.currency,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistorySeries {
  const _HistorySeries({
    required this.supermarketName,
    required this.color,
    required this.points,
  });

  final String supermarketName;
  final Color color;
  final List<ProductPriceHistoryPointDto> points;

  ProductPriceHistoryPointDto get latest => points.last;
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.latestPrice,
    required this.currency,
  });

  final Color color;
  final String label;
  final double latestPrice;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: textStyle),
        const SizedBox(width: 4),
        Text(
          'latest ${latestPrice.toStringAsFixed(2)} $currency',
          style: textStyle?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PriceHistoryChartPainter extends CustomPainter {
  _PriceHistoryChartPainter({
    required this.series,
    required this.colorScheme,
    required this.textStyle,
  });

  final List<_HistorySeries> series;
  final ColorScheme colorScheme;
  final TextStyle? textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final allPoints = series.expand((item) => item.points).toList();
    if (allPoints.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }

    final minTime = allPoints
        .map((point) => point.observedAt.millisecondsSinceEpoch)
        .reduce(math.min);
    final maxTime = allPoints
        .map((point) => point.observedAt.millisecondsSinceEpoch)
        .reduce(math.max);
    final minPriceRaw = allPoints.map((point) => point.price).reduce(math.min);
    final maxPriceRaw = allPoints.map((point) => point.price).reduce(math.max);
    final padding = math.max((maxPriceRaw - minPriceRaw) * 0.08, 1.0);
    final minPrice = math.max(0.0, minPriceRaw - padding);
    final maxPrice = maxPriceRaw + padding;
    final plot = Rect.fromLTWH(
      48,
      14,
      math.max(1, size.width - 60),
      math.max(1, size.height - 48),
    );

    final axisPaint = Paint()
      ..color = colorScheme.outlineVariant
      ..strokeWidth = 1;
    final gridPaint = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.55)
      ..strokeWidth = 1;

    for (final ratio in const [0.0, 0.5, 1.0]) {
      final y = plot.top + plot.height * ratio;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
    }
    canvas.drawLine(plot.topLeft, plot.bottomLeft, axisPaint);
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, axisPaint);

    _drawLabel(canvas, maxPriceRaw.toStringAsFixed(0), Offset(0, plot.top - 6));
    _drawLabel(
      canvas,
      minPriceRaw.toStringAsFixed(0),
      Offset(0, plot.bottom - 8),
    );
    _drawLabel(
      canvas,
      AppFormatters.asShortDate(
        DateTime.fromMillisecondsSinceEpoch(minTime, isUtc: true),
      ),
      Offset(plot.left, plot.bottom + 10),
    );
    _drawLabel(
      canvas,
      AppFormatters.asShortDate(
        DateTime.fromMillisecondsSinceEpoch(maxTime, isUtc: true),
      ),
      Offset(plot.right - 72, plot.bottom + 10),
    );

    for (final item in series) {
      final offsets = item.points
          .map(
            (point) => Offset(
              _scale(
                point.observedAt.millisecondsSinceEpoch.toDouble(),
                minTime.toDouble(),
                maxTime.toDouble(),
                plot.left,
                plot.right,
              ),
              _scale(point.price, minPrice, maxPrice, plot.bottom, plot.top),
            ),
          )
          .toList();

      final linePaint = Paint()
        ..color = item.color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (offsets.length > 1) {
        final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
        for (final offset in offsets.skip(1)) {
          path.lineTo(offset.dx, offset.dy);
        }
        canvas.drawPath(path, linePaint);
      }

      final pointPaint = Paint()..color = item.color;
      final pointBorderPaint = Paint()
        ..color = colorScheme.surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (final offset in offsets) {
        canvas.drawCircle(offset, 4, pointPaint);
        canvas.drawCircle(offset, 4, pointBorderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PriceHistoryChartPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.colorScheme != colorScheme ||
        oldDelegate.textStyle != textStyle;
  }

  double _scale(
    double value,
    double min,
    double max,
    double targetMin,
    double targetMax,
  ) {
    if (max <= min) {
      return (targetMin + targetMax) / 2;
    }
    return targetMin + ((value - min) / (max - min)) * (targetMax - targetMin);
  }

  void _drawLabel(Canvas canvas, String text, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: textStyle?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 90);
    painter.paint(canvas, offset);
  }
}

List<_HistorySeries> _buildSeries(List<ProductPriceHistoryPointDto> points) {
  final grouped = <int, List<ProductPriceHistoryPointDto>>{};
  final sorted = [...points]
    ..sort((a, b) => a.observedAt.compareTo(b.observedAt));
  for (final point in sorted) {
    grouped.putIfAbsent(point.supermarketId, () => []).add(point);
  }

  final entries = grouped.entries.toList()
    ..sort(
      (a, b) => a.value.first.supermarketName.compareTo(
        b.value.first.supermarketName,
      ),
    );

  return [
    for (final entry in entries)
      _HistorySeries(
        supermarketName: entry.value.first.supermarketName,
        color: _marketColor(entry.key, entry.value.first.supermarketName),
        points: entry.value,
      ),
  ];
}

Color _marketColor(int supermarketId, String supermarketName) {
  const marketColorsByName = {
    'tinex': Color(0xFF1A7F64),
    'vero': Color(0xFF2563EB),
    'kam market': Color(0xFFDC2626),
    'ramstore': Color(0xFF9333EA),
    'stokomak': Color(0xFFCA8A04),
    'kit-go market': Color(0xFF0891B2),
    'kipper': Color(0xFFDB2777),
    'zur': Color(0xFF4F46E5),
    'reptil': Color(0xFF0EA5E9),
  };
  final configured = marketColorsByName[_normalizeMarketName(supermarketName)];
  if (configured != null) {
    return configured;
  }
  return HSVColor.fromAHSV(1, (supermarketId * 47) % 360, 0.68, 0.72).toColor();
}

String _normalizeMarketName(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
