import 'package:flutter/material.dart';

import 'package:e_barangay_mo/core/theme/app_colors.dart';
import 'package:e_barangay_mo/core/theme/app_tokens.dart';
import 'package:e_barangay_mo/core/widgets/app_card.dart';
import 'package:e_barangay_mo/core/widgets/press_scale.dart';
import 'package:e_barangay_mo/core/widgets/status_pill.dart';

class ServiceCard extends StatelessWidget {
  const ServiceCard({
    super.key,
    required this.title,
    required this.meta,
    required this.status,
    this.reference,
    this.statusLabel,
    this.icon,
    this.note,
    this.noteMuted = false,
    this.trailing,
    this.onTap,
  });

  final String title;

  /// Reference number shown right after the title, e.g. "BC-2026-0012".
  final String? reference;

  final String meta;
  final String status;
  final String? statusLabel;
  final IconData? icon;

  final String? note;

  final bool noteMuted;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    return PressScale(
      enabled: onTap != null,
      child: AppCard(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Icon(icon, color: c.primary, size: 22),
              ),
              const SizedBox(width: AppSpace.s3),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (reference == null)
                    Text(title, style: text.titleMedium)
                  else
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpace.s2,
                      runSpacing: AppSpace.s1,
                      children: [
                        Text(title, style: text.titleMedium),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.s2, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.primarySoft,
                            borderRadius:
                                BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            reference!,
                            style: text.labelMedium?.copyWith(
                              color: c.primary,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: AppSpace.s1),
                  Text(meta, style: text.bodySmall),
                  if (note != null) ...[
                    const SizedBox(height: AppSpace.s2),
                    Text(note!,
                        style: text.bodySmall?.copyWith(
                            color: noteMuted ? c.inkMuted : c.success,
                            fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpace.s3),
            StatusPill(status, label: statusLabel),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class ServiceCardSkeleton extends StatelessWidget {
  const ServiceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: c.border,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        );

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(AppRadius.full)),
          ),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(160, 16),
                const SizedBox(height: AppSpace.s2),
                bar(220, 12),
              ],
            ),
          ),
          bar(64, 24),
        ],
      ),
    );
  }
}
