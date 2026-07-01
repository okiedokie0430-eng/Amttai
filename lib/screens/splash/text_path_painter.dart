import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A [CustomPainter] that animates a vector path as if a pen is drawing it
/// stroke-by-stroke, using [PathMetrics] and [PathMetric.extractPath].
///
/// Inspired by Cassie Evans' SVG line-drawing animations.
class TextPathPainter extends CustomPainter {
  /// The complete path (may contain multiple contours / sub-paths).
  /// Inject your SVG-converted logo path here.
  final Path path;

  /// 0.0 → stroke invisible, 1.0 → stroke fully drawn.
  final double drawProgress;

  /// 0.0 → no fill, 1.0 → fill fully visible.
  final double fillProgress;

  final Color strokeColor;
  final Color fillColor;
  final double strokeWidth;

  late final Offset _center;

  TextPathPainter({
    required this.path,
    required this.drawProgress,
    required this.fillProgress,
    required this.strokeColor,
    required this.fillColor,
    required this.strokeWidth,
  }) : _center = path.getBounds().center;

  @override
  void paint(Canvas canvas, Size size) {
    final metrics = path.computeMetrics();
    final partialPath = ui.Path();

    // Extract the partial stroke for every contour simultaneously.
    for (final metric in metrics) {
      final drawLength = metric.length * drawProgress;
      final extracted = metric.extractPath(0.0, drawLength);
      partialPath.addPath(extracted, Offset.zero);
    }

    // ── 1. Stroke ──
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 0.6);

    canvas.drawPath(partialPath, strokePaint);

    // ── 2. Fill (soft bloom from center) ──
    if (fillProgress > 0.005) {
      canvas.save();
      canvas.translate(_center.dx, _center.dy);
      // Gentle scale-up as the fill arrives
      canvas.scale(0.94 + 0.06 * fillProgress);
      canvas.translate(-_center.dx, -_center.dy);

      final fillPaint = Paint()
        ..color = fillColor.withValues(alpha: fillProgress)
        ..style = PaintingStyle.fill;

      canvas.drawPath(path, fillPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant TextPathPainter old) {
    return old.drawProgress != drawProgress ||
        old.fillProgress != fillProgress ||
        old.strokeColor != strokeColor ||
        old.fillColor != fillColor ||
        old.strokeWidth != strokeWidth ||
        old.path != path;
  }
}
