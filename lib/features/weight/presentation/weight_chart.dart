import 'dart:math' as math;
import 'package:intl/intl.dart' show DateFormat;
import 'package:liftlog/shared/material.dart';
import '../data/weight_repository.dart';

/// Uses calendar dates as the time axis (including gaps between measurements).
class WeightChart extends StatelessWidget {
  const WeightChart({
    super.key,
    required this.entries,
    required this.onSelected,
  });
  final List<BodyWeight> entries;
  final ValueChanged<BodyWeight> onSelected;
  @override
  Widget build(BuildContext context) {
    final ordered = entries.reversed.toList();
    return LayoutBuilder(
      builder: (context, bounds) => Semantics(
        label:
            'Body weight over time. ${ordered.length} measurements. Tap a point to see its date, weight and note.',
        child: GestureDetector(
          onTapDown: (details) {
            if (ordered.isEmpty) return;
            final positions = chartPoints(ordered, Size(bounds.maxWidth, 240));
            var nearest = 0;
            for (var i = 1; i < positions.length; i++) {
              if ((positions[i] - details.localPosition).distance <
                  (positions[nearest] - details.localPosition).distance) {
                nearest = i;
              }
            }
            onSelected(ordered[nearest]);
          },
          child: CustomPaint(
            size: Size(bounds.maxWidth, 240),
            painter: _WeightPainter(ordered, Theme.of(context).colorScheme),
          ),
        ),
      ),
    );
  }
}

double _time(BodyWeight entry) {
  final d = entry.date;
  return DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch.toDouble();
}

(double, double) _range(List<BodyWeight> entries) {
  final values = entries.map((e) => e.grams / 1000);
  final low = values.reduce(math.min);
  final high = values.reduce(math.max);
  final margin = math.max(0.5, (high - low) * .15);
  return (math.max(0, low - margin), high + margin);
}

List<Offset> chartPoints(List<BodyWeight> ordered, Size size) {
  if (ordered.isEmpty) return [];
  final (low, high) = _range(ordered);
  final start = _time(ordered.first), end = _time(ordered.last);
  return ordered
      .map(
        (e) => Offset(
          52 +
              (end == start ? .5 : (_time(e) - start) / (end - start)) *
                  math.max(1, size.width - 70),
          16 + (high - e.grams / 1000) / (high - low) * (size.height - 56),
        ),
      )
      .toList();
}

class _WeightPainter extends CustomPainter {
  _WeightPainter(this.entries, this.colors);
  final List<BodyWeight> entries;
  final ColorScheme colors;
  void label(Canvas canvas, String text, Offset origin, {bool right = false}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: 11,
          fontFamily: 'Roboto',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      right ? Offset(origin.dx - painter.width, origin.dy) : origin,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;
    final (low, high) = _range(entries);
    final bottom = size.height - 40;
    final grid = Paint()
      ..color = colors.outlineVariant
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = 16 + (bottom - 16) * i / 4;
      canvas.drawLine(Offset(48, y), Offset(size.width - 14, y), grid);
      label(
        canvas,
        (high - (high - low) * i / 4).toStringAsFixed(1),
        Offset(44, y - 6),
        right: true,
      );
    }
    final points = chartPoints(entries, size);
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    for (final point in points) {
      canvas.drawCircle(point, 4, Paint()..color = colors.primary);
    }
    label(canvas, 'kg', const Offset(4, 0));
    final format = DateFormat(
      entries.first.date.year == entries.last.date.year ? 'MMM d' : 'MMM d, yy',
    );
    if (entries.length == 1) {
      label(
        canvas,
        format.format(entries.single.date),
        Offset(points.single.dx - 20, bottom + 10),
      );
    } else {
      label(canvas, format.format(entries.first.date), Offset(48, bottom + 10));
      label(
        canvas,
        format.format(entries.last.date),
        Offset(size.width - 14, bottom + 10),
        right: true,
      );
    }
    label(canvas, 'Date', Offset(size.width / 2 - 10, size.height - 12));
  }

  @override
  bool shouldRepaint(_WeightPainter old) =>
      old.entries != entries || old.colors != colors;
}
