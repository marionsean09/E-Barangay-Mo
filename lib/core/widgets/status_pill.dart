import 'package:flutter/material.dart';

import 'package:e_barangay_mo/core/theme/app_colors.dart';
import 'package:e_barangay_mo/core/theme/app_tokens.dart';

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key, this.label});

  final String status;

  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color background, Color foreground) = switch (status) {
      'Resolved' => (c.success, c.onPrimary),
      'In Progress' => (c.primary, c.onPrimary),
      'Rejected' => (c.danger, c.onPrimary),
      _ => (c.primarySoft, c.primary),
    };

    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label ?? status,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: foreground),
      ),
    );
  }
}
