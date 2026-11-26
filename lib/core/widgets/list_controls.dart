import 'package:flutter/material.dart';

import 'package:e_barangay_mo/core/theme/app_colors.dart';
import 'package:e_barangay_mo/core/theme/app_tokens.dart';
import 'package:e_barangay_mo/core/theme/phosphor_icons.dart';

/// Compact search box for the record lists, with a clear (x) button.
class ListSearchField extends StatelessWidget {
  const ListSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = "Search",
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return SizedBox(
      height: 40,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          maxLength: 100,
          decoration: InputDecoration(
            hintText: hint,
            counterText: "",
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
            prefixIcon: Icon(Icons.search, size: 20, color: c.inkMuted),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: "Clear search",
                    icon: Icon(Icons.close, size: 18, color: c.inkMuted),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.full),
              borderSide: BorderSide(color: c.inkMuted),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.full),
              borderSide: BorderSide(color: c.inkMuted),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Date" button that opens the app's small calendar. Once a day is picked it
/// shows that day, with an x to clear it.
class DateFilterButton extends StatelessWidget {
  const DateFilterButton({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String Function(DateTime) label;

  Future<void> _pick(BuildContext context) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? today,
      firstDate: DateTime(2024),
      lastDate: today,
      helpText: "Show records filed on",
      confirmText: "Show",
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final isActive = value != null;
    final color = isActive ? c.primary : c.ink;

    return Material(
      color: isActive ? c.primarySoft : Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: StadiumBorder(side: BorderSide(color: c.inkMuted)),
      child: InkWell(
        onTap: () => _pick(context),
        child: Container(
          height: 40,
          padding: EdgeInsets.only(
            left: AppSpace.s3,
            right: isActive ? AppSpace.s1 : AppSpace.s3,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIconsRegular.calendarBlank, size: 16, color: color),
              const SizedBox(width: AppSpace.s2),
              Text(
                isActive ? label(value!) : "Date",
                style: text.labelLarge?.copyWith(color: color),
              ),
              if (isActive)
                IconButton(
                  tooltip: "Clear date",
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  icon: Icon(Icons.close, color: color),
                  onPressed: () => onChanged(null),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact dropdown sized and outlined like the Newest/Oldest control.
class FilterMenu extends StatelessWidget {
  const FilterMenu({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final isActive = value != 'All';
    final color = isActive ? c.primary : c.ink;

    return Material(
      color: isActive ? c.primarySoft : Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: StadiumBorder(side: BorderSide(color: c.inkMuted)),
      child: PopupMenuButton<String>(
        tooltip: "Filter by ${label.toLowerCase()}",
        initialValue: value,
        position: PopupMenuPosition.under,
        onSelected: (next) {
          if (next != value) onSelected(next);
        },
        itemBuilder: (_) => [
          for (final entry in options.entries)
            PopupMenuItem(
              value: entry.key,
              child: Text(
                entry.value,
                style: text.bodyMedium?.copyWith(
                  color: entry.key == value ? c.primary : c.ink,
                  fontWeight: entry.key == value
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
        ],
        child: Container(
          height: 40,
          padding: const EdgeInsets.only(left: AppSpace.s4, right: AppSpace.s3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isActive ? options[value]! : label,
                style: text.labelLarge?.copyWith(color: color),
              ),
              const SizedBox(width: AppSpace.s1),
              RotatedBox(
                quarterTurns: 1,
                child: Icon(
                  PhosphorIconsRegular.caretRight,
                  size: 14,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
