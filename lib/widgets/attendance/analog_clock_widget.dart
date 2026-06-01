import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'dart:math' as math;

/// Analog Clock Widget with Animated Clock Hands
class AnalogClockWidget extends StatelessWidget {
  final DateTime dateTime;
  final double size;

  const AnalogClockWidget({super.key, required this.dateTime, this.size = 200});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.1),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: CustomPaint(painter: _ClockPainter(dateTime)),
    );
  }
}

/// Custom Painter for Analog Clock Face
class _ClockPainter extends CustomPainter {
  final DateTime dateTime;

  _ClockPainter(this.dateTime);

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final center = Offset(centerX, centerY);
    final radius = math.min(centerX, centerY);

    // Draw hour markers
    final hourMarkerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30 - 90) * math.pi / 180;
      final x1 = centerX + (radius - 20) * math.cos(angle);
      final y1 = centerY + (radius - 20) * math.sin(angle);
      final x2 = centerX + (radius - 10) * math.cos(angle);
      final y2 = centerY + (radius - 10) * math.sin(angle);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), hourMarkerPaint);
    }

    // Hour hand
    final hourAngle =
        ((dateTime.hour % 12 + dateTime.minute / 60) * 30 - 90) * math.pi / 180;
    final hourHandPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      center,
      Offset(
        centerX + (radius - 50) * math.cos(hourAngle),
        centerY + (radius - 50) * math.sin(hourAngle),
      ),
      hourHandPaint,
    );

    // Minute hand
    final minuteAngle = (dateTime.minute * 6 - 90) * math.pi / 180;
    final minuteHandPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      center,
      Offset(
        centerX + (radius - 30) * math.cos(minuteAngle),
        centerY + (radius - 30) * math.sin(minuteAngle),
      ),
      minuteHandPaint,
    );

    // Second hand
    final secondAngle = (dateTime.second * 6 - 90) * math.pi / 180;
    final secondHandPaint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      center,
      Offset(
        centerX + (radius - 25) * math.cos(secondAngle),
        centerY + (radius - 25) * math.sin(secondAngle),
      ),
      secondHandPaint,
    );

    // Center dot
    final centerDotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, 6, centerDotPaint);
  }

  @override
  bool shouldRepaint(_ClockPainter oldDelegate) {
    return oldDelegate.dateTime != dateTime;
  }
}

// TODO Implement this library.
