import 'dart:async';

import 'package:flutter/material.dart';
import 'package:e_barangay_mo/core/theme/phosphor_icons.dart';

import 'package:e_barangay_mo/features/admin/concern_detail_page.dart';
import 'package:e_barangay_mo/features/profile/profile_menu.dart';
import 'package:e_barangay_mo/core/models/app_user.dart';
import 'package:e_barangay_mo/core/models/concern.dart';
import 'package:e_barangay_mo/core/services/api_service.dart';
import 'package:e_barangay_mo/core/theme/app_colors.dart';
import 'package:e_barangay_mo/core/theme/app_tokens.dart';
import 'package:e_barangay_mo/core/utils/concern_format.dart';
import 'package:e_barangay_mo/core/widgets/brand_logo.dart';
import 'package:e_barangay_mo/core/widgets/hero_panel.dart';
import 'package:e_barangay_mo/core/widgets/notification_bell.dart';
import 'package:e_barangay_mo/core/widgets/service_card.dart';
import 'package:e_barangay_mo/core/widgets/status_pill.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key, required this.user});

  final AppUser user;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late AppUser user = widget.user;
  List<Concern> concerns = [];
  bool isLoading = true;
  String? loadError;
  Map<String, int> counts = {};
  int total = 0;
  String filter = 'All';
  String typeFilter = 'All';
  String sort = 'newest';
  Timer? poller;
  int _loadId = 0;

  static const _typeLabels = {
    'All': 'All types',
    'Request': 'Documents',
    'Blotter': 'Blotter',
    'Complaint': 'Complaints',
    'Suggestion': 'Suggestions',
  };

  @override
  void initState() {
    super.initState();
    loadConcerns();
    // Picks up new submissions from residents.
    poller = Timer.periodic(const Duration(seconds: 30), (_) => loadConcerns());
  }

  @override
  void dispose() {
    poller?.cancel();
    super.dispose();
  }

  Future<void> loadConcerns() async {
    // Only the latest request may update the list if filters change quickly.
    final id = ++_loadId;
    try {
      // Admin-only endpoint: a resident's token gets 403 here.
      final result = await ApiService.adminConcerns(
        sort: sort,
        type: typeFilter == 'All' ? null : typeFilter,
        status: filter == 'All' ? null : filter,
      );
      if (!mounted || id != _loadId) return;
      setState(() {
        concerns = result.concerns;
        counts = result.counts;
        total = result.total;
        isLoading = false;
        loadError = null;
      });
    } on ApiException catch (e) {
      if (!mounted || id != _loadId) return;
      setState(() {
        isLoading = false;
        loadError = e.message;
      });
    }
  }

  void updateView(VoidCallback change) {
    setState(() {
      change();
      isLoading = true;
    });
    loadConcerns();
  }

  Future<void> openDetail(Concern row) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ConcernDetailPage(row: row)),
    );
    if (changed == true) loadConcerns();
  }

  int count(String status) => counts[status] ?? 0;

  static const _overlap = 40.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final name = firstName(user.name);
    final pending = count('Pending');

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: AppSpace.s4,
        title: const BrandLockup(height: 32, onHero: true),
        actions: [
          NotificationBell(onOpen: openDetail, onNewSubmission: loadConcerns),
          IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowClockwise),
            tooltip: "Refresh",
            onPressed: loadConcerns,
          ),
          ProfileMenu(
            user: user,
            onProfileChanged: (u) => setState(() => user = u),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadConcerns,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            HeroPanel(
              overlap: _overlap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? greeting() : "${greeting()}, $name",
                    style: text.headlineMedium?.copyWith(color: c.onHero),
                  ),
                  const SizedBox(height: AppSpace.s6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isLoading && counts.isEmpty ? "-" : "$pending",
                        style: text.headlineMedium?.copyWith(
                          color: c.onHero,
                          fontSize: 64,
                          height: 1,
                          letterSpacing: -2,
                        ),
                      ),
                      const SizedBox(width: AppSpace.s3),
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.s2),
                        child: Text(
                          pending == 1
                              ? "concern waiting\nfor review"
                              : "concerns waiting\nfor review",
                          style: text.bodyLarge?.copyWith(
                            color: c.onHeroMuted,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      HeroOverlap(
                        amount: _overlap,
                        child: _StatCard(
                          pending: pending,
                          pickup: count(readyForPickup),
                          resolved: count('Resolved'),
                          rejected: count('Rejected'),
                        ),
                      ),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpace.s3,
                        runSpacing: AppSpace.s2,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Records", style: text.titleLarge),
                              Text(
                                isLoading
                                    ? "Loading records"
                                    : total > concerns.length
                                    ? "Showing ${concerns.length} of $total"
                                    : "$total ${total == 1 ? 'record' : 'records'}",
                                style: text.bodySmall,
                              ),
                            ],
                          ),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: AppSpace.s2,
                            runSpacing: AppSpace.s2,
                            children: [
                              _FilterMenu(
                                label: "Type",
                                value: typeFilter,
                                options: _typeLabels,
                                onSelected: (value) =>
                                    updateView(() => typeFilter = value),
                              ),
                              _FilterMenu(
                                label: "Status",
                                value: filter,
                                options: {
                                  'All': 'All statuses',
                                  for (final s in concernStatuses) s: s,
                                },
                                onSelected: (value) =>
                                    updateView(() => filter = value),
                              ),
                              SegmentedButton<String>(
                                showSelectedIcon: false,
                                segments: const [
                                  ButtonSegment(
                                    value: 'newest',
                                    label: Text("Newest"),
                                  ),
                                  ButtonSegment(
                                    value: 'oldest',
                                    label: Text("Oldest"),
                                  ),
                                ],
                                selected: {sort},
                                onSelectionChanged: (selection) =>
                                    updateView(() => sort = selection.first),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.s4),
                      ..._list(concerns),
                      const SizedBox(height: AppSpace.s8),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _list(List<Concern> rows) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    if (isLoading) {
      return [
        for (var i = 0; i < 3; i++) ...[
          const ServiceCardSkeleton(),
          const SizedBox(height: AppSpace.s3),
        ],
      ];
    }

    if (loadError != null) {
      return [
        Row(
          children: [
            Icon(PhosphorIconsRegular.warning, color: c.danger),
            const SizedBox(width: AppSpace.s2),
            Expanded(
              child: Text(
                loadError!,
                style: text.bodyMedium?.copyWith(color: c.danger),
              ),
            ),
            TextButton(onPressed: loadConcerns, child: const Text("Retry")),
          ],
        ),
      ];
    }

    if (rows.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
          child: Column(
            children: [
              Icon(PhosphorIconsRegular.tray, size: 40, color: c.inkMuted),
              const SizedBox(height: AppSpace.s3),
              Text(
                filter == 'All' && typeFilter == 'All'
                    ? "No concerns yet"
                    : "No records match these filters",
                style: text.titleMedium,
              ),
              const SizedBox(height: AppSpace.s1),
              Text(
                filter == 'All' && typeFilter == 'All'
                    ? "New requests and reports from residents appear here."
                    : "Try another type or status.",
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ];
    }

    return [
      for (final row in rows) ...[
        ServiceCard(
          icon: typeIcon(row.data['type']),
          title: (row.data['requester'] as Map?)?['fullName'] ?? 'Resident',
          meta:
              "${row.data['title'] ?? ''}\nRef. ${referenceFor(row)}, filed ${formatDateTime(parseDate(row.createdAt) ?? DateTime.now())}",
          status: row.data['status'] ?? 'Pending',
          statusLabel: statusLabel(row.data),
          note: _note(row.data),
          noteMuted:
              (row.data['type'] == 'Blotter' &&
                  parseDate(row.data['finalDate']) == null) ||
              (row.data['type'] == 'Request' &&
                  parseDate(row.data['claimDate']) == null),
          onTap: () => openDetail(row),
        ),
        const SizedBox(height: AppSpace.s3),
      ],
    ];
  }
}

String? _note(Map<String, dynamic> data) {
  if (data['type'] == 'Blotter') {
    final scheduled = parseDate(data['finalDate']);
    if (scheduled != null) return "Scheduled for ${formatLongDate(scheduled)}";
    final requested = parseDate(data['requestedDate']);
    return requested == null
        ? null
        : "Requested ${formatLongDate(requested)}. Needs a final date.";
  }
  final claim = parseDate(data['claimDate']);
  if (claim != null) return "Claim on ${formatLongDate(claim)}";
  if (data['type'] != 'Request') return null;
  final preferred = parseDate(data['requestedDate']);
  return preferred == null
      ? null
      : "Prefers ${formatLongDate(preferred)}. Needs a claiming date.";
}

/// A compact dropdown sized and outlined like the Newest/Oldest control.
class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.pending,
    required this.pickup,
    required this.resolved,
    required this.rejected,
  });

  final int pending;
  final int pickup;
  final int resolved;
  final int rejected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    Widget cell(String status, int value) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s4,
          vertical: AppSpace.s4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("$value", style: text.headlineMedium?.copyWith(height: 1)),
            const SizedBox(height: AppSpace.s2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: StatusPill(status),
            ),
          ],
        ),
      ),
    );

    Widget divider() => VerticalDivider(width: 1, color: c.border);

    Widget row(List<Widget> cells) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: cells,
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.border),
        boxShadow: c.cardShadow,
      ),
      child: MediaQuery.sizeOf(context).width >= 760
          ? row([
              cell('Pending', pending),
              divider(),
              cell(readyForPickup, pickup),
              divider(),
              cell('Resolved', resolved),
              divider(),
              cell('Rejected', rejected),
            ])
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                row([
                  cell('Pending', pending),
                  divider(),
                  cell(readyForPickup, pickup),
                ]),
                Divider(height: 1, color: c.border),
                row([
                  cell('Resolved', resolved),
                  divider(),
                  cell('Rejected', rejected),
                ]),
              ],
            ),
    );
  }
}
