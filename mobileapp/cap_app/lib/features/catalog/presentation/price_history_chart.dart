// File purpose: Renders Flutter UI for catalog feature workflows.
import 'dart:math' as math;

import 'package:cap_app/core/utils/formatters.dart';
import 'package:cap_app/features/catalog/models/catalog_models.dart';
import 'package:cap_app/shared/widgets/market_logo.dart';
import 'package:flutter/material.dart';

class PriceHistoryChart extends StatefulWidget {
  const PriceHistoryChart({required this.points, super.key});

  final List<ProductPriceHistoryPointDto> points;

  @override
  State<PriceHistoryChart> createState() => _PriceHistoryChartState();
}

class _PriceHistoryChartState extends State<PriceHistoryChart> {
  static const _chartHeight = 220.0;

  _SelectedHistoryPoint? _selectedPoint;

  @override
  void didUpdateWidget(covariant PriceHistoryChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.points, widget.points)) {
      _selectedPoint = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final series = _buildSeries(widget.points);
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : MediaQuery.sizeOf(context).width;
                  final chartSize = Size(width, _chartHeight);
                  return SizedBox(
                    height: _chartHeight,
                    width: double.infinity,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) => _selectNearestPoint(
                        details.localPosition,
                        chartSize,
                        series,
                      ),
                      onPanStart: (details) => _selectNearestPoint(
                        details.localPosition,
                        chartSize,
                        series,
                      ),
                      onPanUpdate: (details) => _selectNearestPoint(
                        details.localPosition,
                        chartSize,
                        series,
                      ),
                      child: CustomPaint(
                        key: const ValueKey('price-history-chart-canvas'),
                        painter: _PriceHistoryChartPainter(
                          series: series,
                          colorScheme: theme.colorScheme,
                          textStyle: theme.textTheme.labelSmall,
                          selectedPoint: _selectedPoint,
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (_selectedPoint case final selected?)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _HistoryTooltip(selection: selected),
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

  void _selectNearestPoint(
    Offset localPosition,
    Size size,
    List<_HistorySeries> series,
  ) {
    final layout = _PriceHistoryChartLayout.fromSeries(series, size);
    final nearest = layout.nearestPoint(localPosition);
    if (nearest == null) {
      return;
    }
    setState(() {
      _selectedPoint = _SelectedHistoryPoint(
        point: nearest.point,
        color: nearest.color,
      );
    });
  }
}

class _HistoryTooltip extends StatelessWidget {
  const _HistoryTooltip({required this.selection});

  final _SelectedHistoryPoint selection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final point = selection.point;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: selection.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${point.supermarketName} - ${_formatHistoryPrice(point)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Observed ${AppFormatters.asRelativeDateTime(point.observedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
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

class _SelectedHistoryPoint {
  const _SelectedHistoryPoint({required this.point, required this.color});

  final ProductPriceHistoryPointDto point;
  final Color color;
}

class _HistoryPointLayout {
  const _HistoryPointLayout({
    required this.point,
    required this.color,
    required this.offset,
  });

  final ProductPriceHistoryPointDto point;
  final Color color;
  final Offset offset;
}

class _PriceHistoryChartLayout {
  const _PriceHistoryChartLayout({
    required this.plot,
    required this.minTime,
    required this.maxTime,
    required this.minPriceRaw,
    required this.maxPriceRaw,
    required this.points,
    required this.pointsBySeries,
  });

  final Rect plot;
  final int minTime;
  final int maxTime;
  final double minPriceRaw;
  final double maxPriceRaw;
  final List<_HistoryPointLayout> points;
  final Map<_HistorySeries, List<_HistoryPointLayout>> pointsBySeries;

  static _PriceHistoryChartLayout fromSeries(
    List<_HistorySeries> series,
    Size size,
  ) {
    final allPoints = series.expand((item) => item.points).toList();
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
    final layouts = <_HistoryPointLayout>[];
    final bySeries = <_HistorySeries, List<_HistoryPointLayout>>{};

    for (final item in series) {
      final itemLayouts = [
        for (final point in item.points)
          _HistoryPointLayout(
            point: point,
            color: item.color,
            offset: Offset(
              _scale(
                point.observedAt.millisecondsSinceEpoch.toDouble(),
                minTime.toDouble(),
                maxTime.toDouble(),
                plot.left,
                plot.right,
              ),
              _scale(point.price, minPrice, maxPrice, plot.bottom, plot.top),
            ),
          ),
      ];
      layouts.addAll(itemLayouts);
      bySeries[item] = itemLayouts;
    }

    return _PriceHistoryChartLayout(
      plot: plot,
      minTime: minTime,
      maxTime: maxTime,
      minPriceRaw: minPriceRaw,
      maxPriceRaw: maxPriceRaw,
      points: layouts,
      pointsBySeries: bySeries,
    );
  }

  _HistoryPointLayout? nearestPoint(Offset position) {
    const hitThreshold = 42.0;
    _HistoryPointLayout? nearest;
    var nearestDistance = double.infinity;

    for (final point in points) {
      final distance = (point.offset - position).distance;
      if (distance < nearestDistance) {
        nearest = point;
        nearestDistance = distance;
      }
    }

    for (final item in pointsBySeries.values) {
      if (item.length < 2) {
        continue;
      }
      for (var index = 1; index < item.length; index += 1) {
        final previous = item[index - 1];
        final current = item[index];
        final distance = _distanceToSegment(
          position,
          previous.offset,
          current.offset,
        );
        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearest =
              (previous.offset - position).distance <=
                  (current.offset - position).distance
              ? previous
              : current;
        }
      }
    }

    return nearestDistance <= hitThreshold ? nearest : null;
  }
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
        MarketLogo(supermarketName: label, width: 28, height: 24),
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
    required this.selectedPoint,
  });

  final List<_HistorySeries> series;
  final ColorScheme colorScheme;
  final TextStyle? textStyle;
  final _SelectedHistoryPoint? selectedPoint;

  @override
  void paint(Canvas canvas, Size size) {
    final allPoints = series.expand((item) => item.points).toList();
    if (allPoints.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }

    final layout = _PriceHistoryChartLayout.fromSeries(series, size);
    final plot = layout.plot;

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

    _drawLabel(
      canvas,
      layout.maxPriceRaw.toStringAsFixed(0),
      Offset(0, plot.top - 6),
    );
    _drawLabel(
      canvas,
      layout.minPriceRaw.toStringAsFixed(0),
      Offset(0, plot.bottom - 8),
    );
    _drawLabel(
      canvas,
      AppFormatters.asShortDate(
        DateTime.fromMillisecondsSinceEpoch(layout.minTime, isUtc: true),
      ),
      Offset(plot.left, plot.bottom + 10),
    );
    _drawLabel(
      canvas,
      AppFormatters.asShortDate(
        DateTime.fromMillisecondsSinceEpoch(layout.maxTime, isUtc: true),
      ),
      Offset(plot.right - 72, plot.bottom + 10),
    );

    for (final item in series) {
      final itemPoints =
          layout.pointsBySeries[item] ?? const <_HistoryPointLayout>[];
      final offsets = itemPoints.map((point) => point.offset).toList();

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
      final selectedHaloPaint = Paint()
        ..color = item.color.withValues(alpha: 0.18);
      final selectedBorderPaint = Paint()
        ..color = item.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (final point in itemPoints) {
        final selected =
            selectedPoint != null &&
            _sameHistoryPoint(point.point, selectedPoint!.point);
        if (selected) {
          canvas.drawCircle(point.offset, 10, selectedHaloPaint);
        }
        canvas.drawCircle(point.offset, selected ? 5.5 : 4, pointPaint);
        canvas.drawCircle(point.offset, selected ? 5.5 : 4, pointBorderPaint);
        if (selected) {
          canvas.drawCircle(point.offset, 8, selectedBorderPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PriceHistoryChartPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.colorScheme != colorScheme ||
        oldDelegate.textStyle != textStyle ||
        oldDelegate.selectedPoint != selectedPoint;
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

double _distanceToSegment(Offset point, Offset start, Offset end) {
  final segment = end - start;
  final lengthSquared = segment.dx * segment.dx + segment.dy * segment.dy;
  if (lengthSquared == 0) {
    return (point - start).distance;
  }

  final rawT =
      ((point.dx - start.dx) * segment.dx +
          (point.dy - start.dy) * segment.dy) /
      lengthSquared;
  final t = rawT.clamp(0.0, 1.0).toDouble();
  final projection = Offset(
    start.dx + segment.dx * t,
    start.dy + segment.dy * t,
  );
  return (point - projection).distance;
}

bool _sameHistoryPoint(
  ProductPriceHistoryPointDto left,
  ProductPriceHistoryPointDto right,
) {
  return left.supermarketId == right.supermarketId &&
      left.observedAt == right.observedAt &&
      left.price == right.price;
}

String _formatHistoryPrice(ProductPriceHistoryPointDto point) {
  return '${point.price.toStringAsFixed(2)} ${point.currency}';
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
