import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:e_barangay_mo/core/theme/app_colors.dart';

const _logoRed = Color(0xFFC8102E);
const _logoWhite = Color(0xFFFFF5F6);

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 48, this.onRed = false});

  final double size;
  final bool onRed;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      onRed
          ? 'assets/logos/ebarangay-mark-reversed.svg'
          : 'assets/logos/ebarangay-mark.svg',
      width: size,
      height: size,
      semanticsLabel: 'eBarangay Mo',
    );
  }
}

class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.height = 40,
    this.onHero = false,
    this.showTagline = true,
  });

  final double height;
  final bool onHero;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final nameSize = height * (showTagline ? 0.5 : 0.55);

    return Semantics(
      label: 'eBarangay Mo',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(size: height, onRed: onHero),
            SizedBox(width: height * 0.3),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'eBarangay '),
                    TextSpan(
                      text: 'Mo',
                      style: TextStyle(
                          color: onHero ? c.onHeroMuted : c.primary),
                    ),
                  ]),
                  style: text.titleLarge?.copyWith(
                    fontSize: nameSize,
                    height: 1.05,
                    letterSpacing: -0.02 * nameSize,
                    color: onHero ? c.onHero : c.ink,
                  ),
                ),
                if (showTagline)
                  Text(
                    'SERBISYONG PAMBARANGAY',
                    style: text.labelSmall?.copyWith(
                      fontSize: math.max(8, height * 0.2),
                      letterSpacing: height * 0.2 * 0.18,
                      color: onHero ? c.onHeroMuted : c.inkMuted,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum BrandSealStyle {
  red,

  onRed,

  outline,
}

class BrandSeal extends StatelessWidget {
  const BrandSeal({
    super.key,
    this.size = 200,
    this.style = BrandSealStyle.red,
  });

  final double size;
  final BrandSealStyle style;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color? face, Color ink, String doc) = switch (style) {
      BrandSealStyle.red =>
        (_logoRed, _logoWhite, 'assets/logos/ebarangay-document.svg'),
      BrandSealStyle.onRed =>
        (_logoWhite, _logoRed, 'assets/logos/ebarangay-document-red.svg'),
      BrandSealStyle.outline =>
        (null, c.onHero, 'assets/logos/ebarangay-document.svg'),
    };
    final font = Theme.of(context).textTheme.titleMedium?.fontFamily;

    return Semantics(
      label: 'eBarangay Mo, Serbisyong Pambarangay',
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(size),
              painter: _SealPainter(face: face, ink: ink, fontFamily: font),
            ),
            SvgPicture.asset(doc, height: size * 0.38),
          ],
        ),
      ),
    );
  }
}

class _SealPainter extends CustomPainter {
  _SealPainter({required this.face, required this.ink, this.fontFamily});

  final Color? face;
  final Color ink;
  final String? fontFamily;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = ink
      ..strokeWidth = math.max(1, r * 0.012);

    if (face != null) canvas.drawCircle(center, r, Paint()..color = face!);
    canvas.drawCircle(center, r * 0.945, line);
    canvas.drawCircle(center, r * 0.63, line);

    final dot = Paint()..color = ink;
    canvas.drawCircle(center + Offset(-r * 0.79, 0), r * 0.025, dot);
    canvas.drawCircle(center + Offset(r * 0.79, 0), r * 0.025, dot);

    final style = TextStyle(
      color: ink,
      fontFamily: fontFamily,
      fontSize: r * 0.105,
      fontWeight: FontWeight.w500,
      letterSpacing: r * 0.105 * 0.28,
    );
    _arcText(canvas, center, r * 0.79, 'EBARANGAY MO', style, top: true);
    _arcText(canvas, center, r * 0.79, 'SERBISYONG PAMBARANGAY', style,
        top: false);
  }

  void _arcText(Canvas canvas, Offset center, double radius, String text,
      TextStyle style,
      {required bool top}) {
    final letters = [
      for (final ch in text.characters)
        TextPainter(
          text: TextSpan(text: ch, style: style),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    final total = letters.fold<double>(0, (sum, p) => sum + p.width);
    final sweep = total / radius;

    var angle = top ? -math.pi / 2 - sweep / 2 : math.pi / 2 + sweep / 2;
    for (final p in letters) {
      final step = p.width / radius;
      final mid = top ? angle + step / 2 : angle - step / 2;
      canvas.save();
      canvas.translate(center.dx + radius * math.cos(mid),
          center.dy + radius * math.sin(mid));
      canvas.rotate(top ? mid + math.pi / 2 : mid - math.pi / 2);
      p.paint(canvas, Offset(-p.width / 2, -p.height / 2));
      canvas.restore();
      angle = top ? angle + step : angle - step;
    }
  }

  @override
  bool shouldRepaint(_SealPainter old) =>
      old.face != face || old.ink != ink || old.fontFamily != fontFamily;
}
