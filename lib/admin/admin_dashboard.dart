import 'dart:async';

import 'package:flutter/material.dart';
import 'package:e_barangay_mo/theme/phosphor_icons.dart';

import 'package:e_barangay_mo/admin/concern_detail_page.dart';
import 'package:e_barangay_mo/profile/profile_menu.dart';
import 'package:e_barangay_mo/models/app_user.dart';
import 'package:e_barangay_mo/models/concern.dart';
import 'package:e_barangay_mo/services/api_service.dart';
import 'package:e_barangay_mo/theme/app_colors.dart';
import 'package:e_barangay_mo/theme/app_tokens.dart';
import 'package:e_barangay_mo/utils/concern_format.dart';
import 'package:e_barangay_mo/widgets/brand_logo.dart';
import 'package:e_barangay_mo/widgets/hero_panel.dart';
import 'package:e_barangay_mo/widgets/service_card.dart';
import 'package:e_barangay_mo/widgets/status_pill.dart';

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
  String filter = 'All';
  Timer? poller;

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
    try {
      // Admin-only endpoint: a resident's token gets 403 here.
      final result = await ApiService.allConcerns();
      if (!mounted) return;
      setState(() {
        concerns = result;
        isLoading = false;
        loadError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        loadError = e.message;
      });
    }
  }

  Future<void> openDetail(Concern row) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ConcernDetailPage(row: row)),
    );
    if (changed == true) loadConcerns();
  }

  int count(String status) =>
      concerns.where((r) => (r.data['status'] ?? 'Pending') == status).length;

  static const _overlap = 40.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final name = firstName(user.name);
    final pending = count('Pending');
    final visible = filter == 'All'
        ? concerns
        : concerns
            .where((r) => (r.data['status'] ?? 'Pending') == filter)
            .toList();

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: AppSpace.s4,
        title: const BrandLockup(height: 32, onHero: true),
        actions: [
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
                        isLoading ? "-" : "$pending",
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
                          style: text.bodyLarge
                              ?.copyWith(color: c.onHeroMuted, height: 1.3),
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
                          inProgress: count('In Progress'),
                          resolved: count('Resolved'),
                          rejected: count('Rejected'),
                        ),
                      ),
                      Text("All concerns", style: text.titleLarge),
                      const SizedBox(height: AppSpace.s3),
                      Wrap(
                        spacing: AppSpace.s2,
                        runSpacing: AppSpace.s2,
                        children: [
                          for (final f in ['All', ...concernStatuses])
                            ChoiceChip(
                              label: Text(f),
                              selected: filter == f,
                              showCheckmark: false,
                              onSelected: (_) => setState(() => filter = f),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.s4),
                      ..._list(visible),
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
              child: Text(loadError!,
                  style: text.bodyMedium?.copyWith(color: c.danger)),
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
                filter == 'All' ? "No concerns yet" : "Nothing marked $filter",
                style: text.titleMedium,
              ),
              const SizedBox(height: AppSpace.s1),
              Text(
                "New requests and reports from residents appear here.",
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
          title: row.data['title'] ?? '',
          meta:
              "Ref. ${referenceFor(row)}, filed ${formatDate(parseDate(row.createdAt) ?? DateTime.now())}",
          status: row.data['status'] ?? 'Pending',
          statusLabel: statusLabel(row.data),
          note: _note(row.data),
          noteMuted: row.data['type'] == 'Blotter' &&
              parseDate(row.data['finalDate']) == null,
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
  return claim == null ? null : "Claim on ${formatLongDate(claim)}";
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.inProgress,
    required this.resolved,
    required this.rejected,
  });

  final int inProgress;
  final int resolved;
  final int rejected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    Widget cell(String status, int value) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s4, vertical: AppSpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("$value", style: text.headlineMedium?.copyWith(height: 1)),
                const SizedBox(height: AppSpace.s2),
                StatusPill(status),
              ],
            ),
          ),
        );

    Widget divider() => VerticalDivider(width: 1, color: c.border);

    return Container(
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.border),
        boxShadow: c.cardShadow,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cell('In Progress', inProgress),
            divider(),
            cell('Resolved', resolved),
            divider(),
            cell('Rejected', rejected),
          ],
        ),
      ),
    );
  }
}
