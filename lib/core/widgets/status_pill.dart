import 'package:flutter/material.dart';

import 'package:e_barangay_mo/core/theme/app_colors.dart';
import 'package:e_barangay_mo/core/theme/app_tokens.dart';

const _pickupOrange = Color(0xFFF97316);
const _onPickupOrange = Color(0xFF2A0A10);
const _rejectedRed = Color(0xFFDC2626);
const _onRejectedRed = Color(0xFFFFFFFF);

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key, this.label});

  final String status;

  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color background, Color foreground) = switch (status) {
      'Resolved' => (c.success, c.onPrimary),
      'Ready for Pickup' => (_pickupOrange, _onPickupOrange),
      'Rejected' => (_rejectedRed, _onRejectedRed),
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
