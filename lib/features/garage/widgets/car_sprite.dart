import 'package:flutter/material.dart';

import '../model/car.dart';

class CarSprite extends StatelessWidget {
  const CarSprite({required this.car, super.key});

  final Car car;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CarPainter(car: car),
      child: const SizedBox(height: 148, width: double.infinity),
    );
  }
}

class _CarPainter extends CustomPainter {
  const _CarPainter({required this.car});

  final Car car;

  @override
  void paint(Canvas canvas, Size size) {
    final base = switch (car.tier) {
      CarTier.common => const Color(0xFF6A91A8),
      CarTier.rare => const Color(0xFFD85C4A),
      CarTier.classic => const Color(0xFFD2A84F),
    };
    final isWrecked = car.stage == RestorationStage.wrecked;
    final isStripped = car.stage == RestorationStage.stripped;
    final bodyColor = isWrecked
        ? const Color(0xFF857B70)
        : isStripped
        ? const Color(0xFFB7B0A5)
        : base;
    final body = Paint()..color = bodyColor;
    final dark = Paint()..color = const Color(0xFF2B3339);
    final glass = Paint()..color = const Color(0xFFBFE1E8);
    final accent = Paint()..color = const Color(0xFFF2C14E);

    final x = size.width * .08;
    final y = size.height * .40;
    final w = size.width * .84;
    final h = size.height * .30;
    final bodyPath = Path()
      ..moveTo(x, y + h)
      ..lineTo(x + w * .06, y + h * .35)
      ..quadraticBezierTo(x + w * .20, y - h * .35, x + w * .36, y - h * .33)
      ..lineTo(x + w * .59, y - h * .33)
      ..quadraticBezierTo(x + w * .75, y - h * .28, x + w * .88, y + h * .35)
      ..lineTo(x + w, y + h)
      ..close();
    canvas.drawPath(bodyPath, body);

    final windowPath = Path()
      ..moveTo(x + w * .30, y + h * .06)
      ..lineTo(x + w * .42, y - h * .23)
      ..lineTo(x + w * .56, y - h * .23)
      ..lineTo(x + w * .68, y + h * .06)
      ..close();
    canvas.drawPath(windowPath, glass);
    canvas.drawLine(
      Offset(x + w * .50, y - h * .20),
      Offset(x + w * .50, y + h * .04),
      Paint()
        ..color = const Color(0xFF53666A)
        ..strokeWidth = 3,
    );

    for (final wheelX in [x + w * .24, x + w * .76]) {
      canvas.drawCircle(Offset(wheelX, y + h), h * .42, dark);
      canvas.drawCircle(Offset(wheelX, y + h), h * .19, accent);
    }

    if (car.stage.index >= RestorationStage.repaired.index) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + w * .70, y + h * .34, w * .20, h * .12),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFFFAE0A0),
      );
    }

    if (isWrecked) {
      final scratch = Paint()
        ..color = const Color(0xFF4B4640)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(x + w * .16, y + h * .15),
        Offset(x + w * .29, y + h * .52),
        scratch,
      );
      canvas.drawLine(
        Offset(x + w * .80, y + h * .08),
        Offset(x + w * .70, y + h * .50),
        scratch,
      );
      canvas.drawCircle(Offset(x + w * .57, y + h * .28), 5, scratch);
    }

    if (car.stage == RestorationStage.detailed) {
      final shine = Paint()
        ..color = Colors.white.withValues(alpha: .72)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(x + w * .40, y + h * .28),
        Offset(x + w * .58, y + h * .14),
        shine,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CarPainter oldDelegate) =>
      oldDelegate.car.stage != car.stage || oldDelegate.car.tier != car.tier;
}
