import 'package:flutter/material.dart';

import 'package:e_barangay_mo/core/theme/app_colors.dart';
import 'package:e_barangay_mo/core/theme/app_tokens.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.s4),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = BorderRadius.circular(AppRadius.md);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: radius,
        border: Border.all(color: c.border),
        boxShadow: c.cardShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
