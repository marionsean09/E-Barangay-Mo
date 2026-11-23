import 'package:flutter/material.dart';

import 'package:e_barangay_mo/core/theme/app_colors.dart';
import 'package:e_barangay_mo/core/theme/app_tokens.dart';
import 'package:e_barangay_mo/core/widgets/brand_logo.dart';

class HeroPanel extends StatelessWidget {
  const HeroPanel({
    super.key,
    required this.child,
    this.overlap = 0,
    this.showArt = true,
  });

  final Widget child;
  final double overlap;
  final bool showArt;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      decoration: BoxDecoration(
        gradient: c.heroGradient,
        borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(AppRadius.lg)),
      ),
      padding: EdgeInsets.fromLTRB(
          AppSpace.s4, AppSpace.s6, AppSpace.s4, AppSpace.s8 + overlap),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final content = Align(alignment: Alignment.centerLeft, child: child);
              if (!showArt || constraints.maxWidth < 720) return content;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: content),
                  const SizedBox(width: AppSpace.s6),
                  const BrandSeal(size: 168, style: BrandSealStyle.outline),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class HeroOverlap extends StatelessWidget {
  const HeroOverlap({super.key, required this.amount, required this.child});

  final double amount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, -amount),
      child: child,
    );
  }
}
