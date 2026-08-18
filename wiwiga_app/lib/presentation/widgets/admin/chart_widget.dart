// ============================================================
// Fichier: chart_widget.dart
// Description: Widgets de graphiques admin (CustomPaint)
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';

/// Graphique en courbe (line chart) pour les métriques
class AdminLineChart extends StatelessWidget {
  final List<double> data;
  final Color lineColor;
  final String? label;
  final double height;
  final bool showDots;
  final List<String>? xLabels;

  const AdminLineChart({
    super.key,
    required this.data,
    this.lineColor = NeonColors.primary,
    this.label,
    this.height = 150,
    this.showDots = true,
    this.xLabels,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeonColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: const TextStyle(
                color: NeonColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _LineChartPainter(
                data: data,
                lineColor: lineColor,
                showDots: showDots,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Graphique en barres pour les métriques
class AdminBarChart extends StatelessWidget {
  final List<double> data;
  final Color barColor;
  final String? label;
  final double height;
  final List<String>? labels;

  const AdminBarChart({
    super.key,
    required this.data,
    this.barColor = NeonColors.accent,
    this.label,
    this.height = 150,
    this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeonColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: const TextStyle(
                color: NeonColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _BarChartPainter(
                data: data,
                barColor: barColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sparkline compact pour les KPI cards
class AdminSparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double height;
  final double width;

  const AdminSparkline({
    super.key,
    required this.data,
    this.color = NeonColors.primary,
    this.height = 30,
    this.width = 80,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _LineChartPainter(
          data: data,
          lineColor: color,
          showDots: false,
          lineWidth: 1.5,
        ),
      ),
    );
  }
}

// ========================================
// PAINTERS
// ========================================

class _LineChartPainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;
  final bool showDots;
  final double lineWidth;

  _LineChartPainter({
    required this.data,
    required this.lineColor,
    this.showDots = true,
    this.lineWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || data.length < 2) return;

    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final minVal = data.reduce((a, b) => a < b ? a : b);
    final range = maxVal - minVal;
    if (range == 0) return;

    final stepX = size.width / (data.length - 1);
    final padding = size.height * 0.1;
    final chartHeight = size.height - 2 * padding;

    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = padding + chartHeight - ((data[i] - minVal) / range) * chartHeight;
      points.add(Offset(x, y));
    }

    // Gradient fill sous la courbe
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lineColor.withValues(alpha: 0.3), lineColor.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final fillPath = Path();
    fillPath.moveTo(points.first.dx, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // Ligne
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      // Courbe lissée (quadratic bezier)
      final prev = points[i - 1];
      final curr = points[i];
      final midX = (prev.dx + curr.dx) / 2;
      path.quadraticBezierTo(prev.dx + (midX - prev.dx) * 0.5, prev.dy, midX, (prev.dy + curr.dy) / 2);
      path.quadraticBezierTo(curr.dx - (curr.dx - midX) * 0.5, curr.dy, curr.dx, curr.dy);
    }
    canvas.drawPath(path, linePaint);

    // Points
    if (showDots && data.length <= 30) {
      final dotPaint = Paint()..color = lineColor;
      for (final p in points) {
        canvas.drawCircle(p, 2.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _BarChartPainter extends CustomPainter {
  final List<double> data;
  final Color barColor;

  _BarChartPainter({required this.data, required this.barColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxVal = data.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return;

    final barWidth = (size.width / data.length) * 0.7;
    final gap = (size.width / data.length) * 0.3;
    final padding = size.height * 0.05;
    final chartHeight = size.height - 2 * padding;

    for (int i = 0; i < data.length; i++) {
      final barHeight = (data[i] / maxVal) * chartHeight;
      final x = i * (barWidth + gap) + gap / 2;
      final y = padding + chartHeight - barHeight;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(3),
      );

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [barColor, barColor.withValues(alpha: 0.5)],
        ).createShader(Rect.fromLTWH(x, y, barWidth, barHeight));

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
