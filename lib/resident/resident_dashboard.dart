import 'dart:async';

import 'package:flutter/material.dart';
import 'package:e_barangay_mo/theme/phosphor_icons.dart';

import 'package:e_barangay_mo/profile/profile_menu.dart';
import 'package:e_barangay_mo/resident/submit_concern_page.dart';
import 'package:e_barangay_mo/models/app_user.dart';
import 'package:e_barangay_mo/models/concern.dart';
import 'package:e_barangay_mo/services/api_service.dart';
import 'package:e_barangay_mo/theme/app_colors.dart';
import 'package:e_barangay_mo/theme/app_tokens.dart';
import 'package:e_barangay_mo/utils/concern_format.dart';
import 'package:e_barangay_mo/widgets/brand_logo.dart';
import 'package:e_barangay_mo/widgets/hero_panel.dart';
import 'package:e_barangay_mo/widgets/press_scale.dart';
import 'package:e_barangay_mo/widgets/service_card.dart';

class ResidentDashboard extends StatefulWidget {
  const ResidentDashboard({super.key, required this.user});

  final AppUser user;

  @override
  State<ResidentDashboard> createState() => _ResidentDashboardState();
}

class _ResidentDashboardState extends State<ResidentDashboard> {
  late AppUser user = widget.user;
  List<Concern> concerns = [];
  bool isLoading = true;
  String filter = 'All';
  String? loadError;
  Timer? poller;

  @override
  void initState() {
    super.initState();
    loadConcerns();
    // Picks up status changes made by the barangay.
    poller = Timer.periodic(const Duration(seconds: 30), (_) => loadConcerns());
  }

  @override
  void dispose() {
    poller?.cancel();
    super.dispose();
  }

  Future<void> loadConcerns() async {
    try {
      // The server returns only this user's concerns (filtered by the
      // token's user, not by anything the app sends).
      final result = await ApiService.myConcerns();
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

  Future<void> openForm(String type) async {
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SubmitConcernPage(initialType: type)),
    );
    if (submitted == true) loadConcerns();
  }

  static const _overlap = 40.0;

  int get openCount => concerns.where((r) {
        final status = r.data['status'] ?? 'Pending';
        return status == 'Pending' || status == 'In Progress';
      }).length;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final name = firstName(user.name);
    final open = openCount;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: AppSpace.s4,
        title: const BrandLockup(height: 32, onHero: true),
        actions: [
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
                  const SizedBox(height: AppSpace.s2),
                  Text(
                    isLoading || loadError != null
                        ? "Barangay services, one tap away."
                        : switch (open) {
                            0 => "You have no open requests.",
                            1 => "You have 1 open request.",
                            _ => "You have $open open requests.",
                          },
                    style: text.bodyLarge?.copyWith(color: c.onHeroMuted),
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
                        child: _QuickActions(onOpen: openForm),
                      ),
                      Text("My requests", style: text.titleLarge),
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
                      ..._requestList(),
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

  List<Widget> _requestList() {
    final text = Theme.of(context).textTheme;
    final c = context.colors;

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

    final visible = filter == 'All'
        ? concerns
        : concerns
            .where((r) => (r.data['status'] ?? 'Pending') == filter)
            .toList();

    if (concerns.isNotEmpty && visible.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
          child: Column(
            children: [
              Icon(PhosphorIconsRegular.tray, size: 40, color: c.inkMuted),
              const SizedBox(height: AppSpace.s3),
              Text("Nothing marked $filter", style: text.titleMedium),
              const SizedBox(height: AppSpace.s1),
              TextButton(
                onPressed: () => setState(() => filter = 'All'),
                child: const Text("Show all"),
              ),
            ],
          ),
        ),
      ];
    }

    if (concerns.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
          child: Column(
            children: [
              Icon(PhosphorIconsRegular.clipboardText,
                  size: 40, color: c.inkMuted),
              const SizedBox(height: AppSpace.s3),
              Text("No requests yet", style: text.titleMedium),
              const SizedBox(height: AppSpace.s1),
              Text(
                "Documents you request and reports you file will show here.",
                style: text.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ];
    }

    return [
      for (final row in visible) ...[
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
        ),
        const SizedBox(height: AppSpace.s3),
      ],
    ];
  }

  String? _note(Map<String, dynamic> data) {
    if (data['type'] == 'Blotter') {
      final scheduled = parseDate(data['finalDate']);
      if (scheduled != null) {
        return "Scheduled for ${formatLongDate(scheduled)} at the barangay hall";
      }
      final requested = parseDate(data['requestedDate']);
      return requested == null
          ? null
          : "You asked for ${formatLongDate(requested)}. Waiting for confirmation.";
    }
    final date = parseDate(data['claimDate']);
    if (date == null) return null;
    return "Claim on ${formatLongDate(date)} at the barangay hall";
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(AppRadius.md);

    final primary = PressScale(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.heroBright, c.primary, c.primaryStrong],
          ),
          border: Border.all(color: c.onHero.withValues(alpha: 0.18)),
          boxShadow: c.cardShadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => onOpen('Request'),
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: c.onHero.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Icon(PhosphorIconsRegular.fileText,
                            color: c.onHero, size: 24),
                      ),
                      const Spacer(),
                      Icon(PhosphorIconsRegular.arrowUpRight,
                          color: c.onHero),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s8),
                  Text("Request a document",
                      style: text.titleLarge?.copyWith(color: c.onHero)),
                  const SizedBox(height: AppSpace.s1),
                  Text(
                    "Clearance, residency, indigency, business permit",
                    style: text.bodySmall?.copyWith(color: c.onHeroMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Widget secondary(IconData icon, String label, String hint, String type) {
      return PressScale(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: radius,
            border: Border.all(color: c.border),
            boxShadow: c.cardShadow,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => onOpen(type),
              borderRadius: radius,
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s4),
                child: Row(
                  children: [
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: text.titleMedium),
                          Text(hint, style: text.bodySmall),
                        ],
                      ),
                    ),
                    Icon(PhosphorIconsRegular.caretRight, color: c.inkMuted),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final others = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        secondary(PhosphorIconsRegular.megaphone, "Report a concern",
            "Noise, roads, peace and order", 'Complaint'),
        const SizedBox(height: AppSpace.s3),
        secondary(PhosphorIconsRegular.scales, "File a blotter report",
            "Request a date at the barangay hall", 'Blotter'),
        const SizedBox(height: AppSpace.s3),
        secondary(PhosphorIconsRegular.lightbulb, "Share a suggestion",
            "Ideas for the barangay", 'Suggestion'),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [primary, const SizedBox(height: AppSpace.s3), others],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: primary),
              const SizedBox(width: AppSpace.s3),
              Expanded(flex: 2, child: others),
            ],
          ),
        );
      },
    );
  }
}
