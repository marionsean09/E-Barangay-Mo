import 'package:flutter/material.dart';
import 'package:e_barangay_mo/core/theme/phosphor_icons.dart';

import 'package:e_barangay_mo/features/resident/request_options.dart';
import 'package:e_barangay_mo/core/models/concern.dart';
import 'package:e_barangay_mo/core/services/api_service.dart';
import 'package:e_barangay_mo/core/theme/app_colors.dart';
import 'package:e_barangay_mo/core/theme/app_tokens.dart';
import 'package:e_barangay_mo/core/utils/concern_format.dart';
import 'package:e_barangay_mo/core/widgets/app_card.dart';
import 'package:e_barangay_mo/core/widgets/concern_photos.dart';
import 'package:e_barangay_mo/core/widgets/concern_receipt.dart';
import 'package:e_barangay_mo/core/widgets/concern_thread.dart';
import 'package:e_barangay_mo/core/widgets/press_scale.dart';
import 'package:e_barangay_mo/core/widgets/status_pill.dart';

class ConcernDetailPage extends StatefulWidget {
  const ConcernDetailPage({super.key, required this.row});

  final Concern row;

  @override
  State<ConcernDetailPage> createState() => _ConcernDetailPageState();
}

class _ConcernDetailPageState extends State<ConcernDetailPage> {
  late Map<String, dynamic> data = Map.of(widget.row.data);
  String? get requesterName =>
      (data['requester'] as Map?)?['fullName'] as String?;
  bool isSaving = false;
  bool changed = false;

  bool get isRequest => data['type'] == 'Request';
  bool get isBlotter => data['type'] == 'Blotter';
  bool get isClosed => isClosedStatus(data['status']);
  DateTime? get requestedDate => parseDate(data['requestedDate']);
  DateTime? get finalDate => parseDate(data['finalDate']);

  List<(String, int?)> get photos {
    if (isRequest) {
      return [
        for (final entry in requirementLabels.entries)
          (entry.value, data[entry.key] as int?),
      ];
    }
    final evidence = (data['evidence'] as List?)?.cast<int>() ?? [];
    return [
      for (var i = 0; i < evidence.length; i++) ("Photo ${i + 1}", evidence[i]),
    ];
  }

  DateTime? get claimDate => parseDate(data['claimDate']);

  /// [update] keys: status, final_date, claim_date. The server validates
  /// them, records who changed what in the audit log, and returns the
  /// saved concern, which replaces the local copy.
  Future<void> save(Map<String, dynamic> update, String message) async {
    setState(() => isSaving = true);
    try {
      final saved = await ApiService.updateConcern(widget.row.id, update);
      if (!mounted) return;
      setState(() {
        data = Map.of(saved.data);
        changed = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  /// Resolving or rejecting is permanent, so it asks first.
  Future<void> changeStatus(String next) async {
    final name = statusName(data['type'] as String?, next);
    if (isClosedStatus(next)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text("Mark as ${name.toLowerCase()}?"),
          content: const Text(
            "This is final. Its status, dates and replies can no longer be changed.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text("Mark as ${name.toLowerCase()}"),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await save({'status': next}, "Marked as $name");
  }

  Future<void> pickClaimDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    // The picker requires a selectable start day: not past, not a weekend.
    var initial =
        claimDate ?? requestedDate ?? today.add(const Duration(days: 1));
    if (initial.isBefore(today)) initial = today;
    while (initial.weekday > DateTime.friday) {
      initial = initial.add(const Duration(days: 1));
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: today.add(const Duration(days: 180)),
      helpText: "Claiming date",
      confirmText: "Set date",
      selectableDayPredicate: (day) => day.weekday <= DateTime.friday,
    );
    if (picked == null) return;

    await setClaimDate(
      picked,
      "Claiming date set to ${formatLongDate(picked)}",
    );
  }

  Future<void> setClaimDate(DateTime day, String message) async {
    await save({'claim_date': apiDate(day), 'status': readyForPickup}, message);
  }

  Future<void> setFinalDate(DateTime day, String message) async {
    await save({'final_date': apiDate(day), 'status': 'Pending'}, message);
  }

  Future<void> pickFinalDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    var initial = finalDate ?? requestedDate ?? today;
    if (initial.isBefore(today)) initial = today;
    while (initial.weekday > DateTime.friday) {
      initial = initial.add(const Duration(days: 1));
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: today.add(const Duration(days: 180)),
      helpText: "Final date",
      confirmText: "Set date",
      selectableDayPredicate: (day) => day.weekday <= DateTime.friday,
    );
    if (picked == null) return;
    await setFinalDate(picked, "Final date set to ${formatLongDate(picked)}");
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final String status = data['status'] ?? 'Pending';
    final filed = parseDate(widget.row.createdAt) ?? DateTime.now();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, changed);
      },
      child: Scaffold(
        appBar: AppBar(title: Text("Ref. ${referenceFor(widget.row)}")),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpace.s2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          data['title'] ?? '',
                          style: text.headlineMedium,
                        ),
                      ),
                      const SizedBox(width: AppSpace.s3),
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpace.s2),
                        child: StatusPill(status, label: statusLabel(data)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s2),
                  Text(
                    "${data['type']} from ${requesterName ?? 'a resident'}, filed ${formatDate(filed)}",
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: AppSpace.s6),
                  ConcernReceipt(
                    concern: Concern(
                      id: widget.row.id,
                      createdAt: widget.row.createdAt,
                      data: data,
                    ),
                  ),
                  const SizedBox(height: AppSpace.s4),

                  if (isRequest) ...[
                    _claimCard(),
                    const SizedBox(height: AppSpace.s4),
                  ],
                  if (isBlotter) ...[
                    _scheduleCard(),
                    const SizedBox(height: AppSpace.s4),
                  ],

                  AppCard(
                    padding: const EdgeInsets.all(AppSpace.s6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRequest
                              ? "Purpose"
                              : isBlotter
                              ? "Reason"
                              : "Details",
                          style: text.titleMedium,
                        ),
                        const SizedBox(height: AppSpace.s2),
                        Text(
                          (isRequest ? data['purpose'] : data['description']) ??
                              '',
                          style: text.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.s4),

                  if (data['type'] == 'Complaint') ...[
                    ConcernThread(concernId: widget.row.id, readOnly: isClosed),
                    const SizedBox(height: AppSpace.s4),
                  ],

                  if (isRequest || isBlotter) ...[
                    AppCard(
                      padding: const EdgeInsets.all(AppSpace.s6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isRequest ? "Requirements" : "Photos",
                            style: text.titleMedium,
                          ),
                          const SizedBox(height: AppSpace.s4),
                          if (photos.isEmpty)
                            Text("No photos attached.", style: text.bodySmall)
                          else
                            ConcernPhotoGrid(photos: photos),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.s4),
                  ],

                  AppCard(
                    padding: const EdgeInsets.all(AppSpace.s6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Status", style: text.titleMedium),
                        const SizedBox(height: AppSpace.s3),
                        if (isClosed)
                          Text(
                            "${statusLabel(data)}. This record is final and can no longer be changed.",
                            style: text.bodyMedium,
                          )
                        else
                          Wrap(
                            spacing: AppSpace.s2,
                            runSpacing: AppSpace.s2,
                            children: [
                              for (final s in statusesFor(data['type']))
                                ChoiceChip(
                                  label: Text(statusName(data['type'] as String?, s)),
                                  selected: status == s,
                                  showCheckmark: false,
                                  onSelected: (_) {
                                    if (isSaving || status == s) return;
                                    changeStatus(s);
                                  },
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (isSaving) ...[
                    const SizedBox(height: AppSpace.s4),
                    LinearProgressIndicator(
                      color: c.primary,
                      backgroundColor: c.primarySoft,
                    ),
                  ],
                  const SizedBox(height: AppSpace.s8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _scheduleCard() {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final requested = requestedDate;
    final scheduled = finalDate;
    final canApprove =
        requested != null &&
        !requested.isBefore(DateUtils.dateOnly(DateTime.now())) &&
        (scheduled == null || !DateUtils.isSameDay(scheduled, requested));

    return Container(
      padding: const EdgeInsets.all(AppSpace.s6),
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIconsRegular.calendarCheck, color: c.primary),
              const SizedBox(width: AppSpace.s2),
              Text(
                "Blotter schedule",
                style: text.titleMedium?.copyWith(color: c.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            "Requested by the resident",
            style: text.bodySmall?.copyWith(color: c.primary),
          ),
          Text(
            requested == null ? "No date given" : formatLongDate(requested),
            style: text.titleMedium?.copyWith(color: c.primary),
          ),
          const SizedBox(height: AppSpace.s3),
          Text("Final date", style: text.bodySmall?.copyWith(color: c.primary)),
          Text(
            scheduled == null ? "Not set yet" : formatLongDate(scheduled),
            style: text.titleLarge?.copyWith(color: c.primary),
          ),
          const SizedBox(height: AppSpace.s1),
          Text(
            isClosed
                ? "This record is final."
                : scheduled == null
                ? "Approve the requested date or set another one. The resident sees the final date on their home screen."
                : "The resident sees this date on their home screen.",
            style: text.bodyMedium?.copyWith(color: c.primary),
          ),
          if (!isClosed) const SizedBox(height: AppSpace.s4),
          if (!isClosed)
            Wrap(
              spacing: AppSpace.s2,
              runSpacing: AppSpace.s2,
              children: [
                if (canApprove) ...[
                  PressScale(
                    enabled: !isSaving,
                    child: ElevatedButton.icon(
                      icon: const Icon(PhosphorIconsRegular.checkCircle),
                      label: const Text("Approve requested date"),
                      onPressed: isSaving
                          ? null
                          : () => setFinalDate(
                              requested,
                              "Approved ${formatLongDate(requested)}",
                            ),
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(PhosphorIconsRegular.calendarPlus),
                    label: Text(
                      scheduled == null ? "Set another date" : "Change date",
                    ),
                    onPressed: isSaving ? null : pickFinalDate,
                  ),
                ] else
                  PressScale(
                    enabled: !isSaving,
                    child: ElevatedButton.icon(
                      icon: const Icon(PhosphorIconsRegular.calendarPlus),
                      label: Text(
                        scheduled == null ? "Set final date" : "Change date",
                      ),
                      onPressed: isSaving ? null : pickFinalDate,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _claimCard() {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final date = claimDate;
    final preferred = requestedDate;
    final canApprove =
        preferred != null &&
        !preferred.isBefore(DateUtils.dateOnly(DateTime.now())) &&
        (date == null || !DateUtils.isSameDay(date, preferred));

    return Container(
      padding: const EdgeInsets.all(AppSpace.s6),
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIconsRegular.calendarCheck, color: c.primary),
              const SizedBox(width: AppSpace.s2),
              Text(
                "Claiming date",
                style: text.titleMedium?.copyWith(color: c.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            "Preferred by the resident",
            style: text.bodySmall?.copyWith(color: c.primary),
          ),
          Text(
            preferred == null ? "No date given" : formatLongDate(preferred),
            style: text.titleMedium?.copyWith(color: c.primary),
          ),
          const SizedBox(height: AppSpace.s3),
          Text(
            "Claiming date",
            style: text.bodySmall?.copyWith(color: c.primary),
          ),
          Text(
            date == null ? "Not set yet" : formatLongDate(date),
            style: text.titleLarge?.copyWith(color: c.primary),
          ),
          const SizedBox(height: AppSpace.s1),
          Text(
            isClosed
                ? "This record is final."
                : date == null
                ? "Approve the preferred date or set another one. The resident sees the claiming date on their home screen."
                : "The resident sees this date on their home screen.",
            style: text.bodyMedium?.copyWith(color: c.primary),
          ),
          if (!isClosed) const SizedBox(height: AppSpace.s4),
          if (!isClosed)
            Wrap(
              spacing: AppSpace.s2,
              runSpacing: AppSpace.s2,
              children: [
                if (canApprove) ...[
                  PressScale(
                    enabled: !isSaving,
                    child: ElevatedButton.icon(
                      icon: const Icon(PhosphorIconsRegular.checkCircle),
                      label: const Text("Approve preferred date"),
                      onPressed: isSaving
                          ? null
                          : () => setClaimDate(
                              preferred,
                              "Approved ${formatLongDate(preferred)}",
                            ),
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(PhosphorIconsRegular.calendarPlus),
                    label: Text(
                      date == null ? "Set another date" : "Change date",
                    ),
                    onPressed: isSaving ? null : pickClaimDate,
                  ),
                ] else
                  PressScale(
                    enabled: !isSaving,
                    child: ElevatedButton.icon(
                      icon: const Icon(PhosphorIconsRegular.calendarPlus),
                      label: Text(date == null ? "Set date" : "Change date"),
                      onPressed: isSaving ? null : pickClaimDate,
                    ),
                  ),
                if (date != null)
                  OutlinedButton(
                    onPressed: isSaving
                        ? null
                        : () => save({
                            'claim_date': null,
                            if (data['status'] == readyForPickup)
                              'status': 'Pending',
                          }, "Claiming date cleared"),
                    child: const Text("Clear"),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
