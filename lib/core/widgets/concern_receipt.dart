import 'package:flutter/material.dart';

import 'package:e_barangay_mo/core/models/concern.dart';
import 'package:e_barangay_mo/core/theme/app_colors.dart';
import 'package:e_barangay_mo/core/theme/app_tokens.dart';
import 'package:e_barangay_mo/core/utils/concern_format.dart';
import 'package:e_barangay_mo/core/widgets/brand_logo.dart';
import 'package:e_barangay_mo/core/widgets/status_pill.dart';
import 'package:e_barangay_mo/features/resident/request_options.dart';

/// A printed-slip view of one submission. It records what was filed and is
/// deliberately not an official receipt: no payment is taken in the app.
class ConcernReceipt extends StatelessWidget {
  const ConcernReceipt({super.key, required this.concern});

  final Concern concern;

  Map<String, dynamic> get data => concern.data;
  String get status => data['status'] ?? 'Pending';
  bool get isRequest => data['type'] == 'Request';
  bool get isBlotter => data['type'] == 'Blotter';

  String get serviceName => switch (data['type']) {
    'Request' => 'Document request',
    'Blotter' => 'Blotter report',
    'Suggestion' => 'Suggestion',
    _ => 'Complaint',
  };

  String _date(String key, String fallback) {
    final date = parseDate(data[key] as String?);
    return date == null ? fallback : formatLongDate(date);
  }

  String get _claimFallback => switch (status) {
    readyForPickup => 'Ready, date not set',
    'Resolved' => 'Completed',
    'Rejected' => 'Not applicable',
    _ => 'Waiting for confirmation',
  };

  String get _hearingFallback => switch (status) {
    'Resolved' => 'Settled',
    'Rejected' => 'Not applicable',
    _ => 'Waiting for confirmation',
  };

  String _time(DateTime date) {
    final full = formatDateTime(date);
    return full.substring(full.lastIndexOf(', ') + 2);
  }

  String get _footer {
    final notice = isRequest
        ? "This is a submission record, not an official receipt. The Barangay Treasurer's Office issues an official receipt when you pay."
        : "This is a submission record, not an official receipt.";
    if (isClosedStatus(status)) return notice;
    final action = isRequest
        ? "Bring this reference number, your valid ID and your Cedula when claiming."
        : isBlotter
        ? "Bring this reference number and a valid ID to the barangay hall on your final date."
        : "Keep this reference number for follow-ups.";
    return "$action\n$notice";
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final filed = parseDate(concern.createdAt);
    final filedBy = (data['requester'] as Map?)?['fullName'] as String?;
    final title = data['title'] as String? ?? '';
    // Written as PHP because the app's font has no peso sign.
    final fee = requestFees[data['requestType']]?.replaceAll('₱', 'PHP ');

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: PhysicalShape(
          clipper: const _TornEdgeClipper(),
          color: c.surfaceRaised,
          elevation: 1,
          shadowColor: c.ink.withValues(alpha: 0.16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s6,
              AppSpace.s6,
              AppSpace.s6,
              AppSpace.s8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: BrandMark(size: 44)),
                const SizedBox(height: AppSpace.s2),
                Text(
                  "eBarangay Mo",
                  textAlign: TextAlign.center,
                  style: text.titleLarge,
                ),
                Text(
                  "SERBISYONG PAMBARANGAY",
                  textAlign: TextAlign.center,
                  style: text.labelSmall?.copyWith(
                    color: c.inkMuted,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: AppSpace.s4),
                Text(
                  "SUBMISSION RECEIPT",
                  textAlign: TextAlign.center,
                  style: text.titleMedium?.copyWith(letterSpacing: 2.4),
                ),
                const _DashedLine(),
                Text(
                  "REFERENCE NO.",
                  textAlign: TextAlign.center,
                  style: text.labelSmall?.copyWith(
                    color: c.inkMuted,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpace.s1),
                Text(
                  referenceFor(concern),
                  textAlign: TextAlign.center,
                  style: text.headlineSmall?.copyWith(
                    letterSpacing: 1.2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: AppSpace.s2),
                Center(
                  child: IntrinsicWidth(
                    child: StatusPill(status, label: statusLabel(data)),
                  ),
                ),
                const _DashedLine(),
                const _SectionLabel("Filing"),
                if (filed != null) ...[
                  _ReceiptRow("Date filed", formatLongDate(filed)),
                  _ReceiptRow("Time filed", _time(filed)),
                ],
                if (filedBy != null) _ReceiptRow("Filed by", filedBy),
                const _DashedLine(),
                const _SectionLabel("Service"),
                _ReceiptRow("Service", serviceName),
                if (isRequest)
                  _ReceiptRow("Document", data['requestType'] ?? title)
                else if (isBlotter)
                  _ReceiptRow("Category", title.replaceFirst('Blotter: ', ''))
                else
                  _ReceiptRow("Subject", title),
                if (isRequest || isBlotter) ...[
                  const _DashedLine(),
                  const _SectionLabel("Schedule"),
                  if (isRequest) ...[
                    _ReceiptRow(
                      "Preferred date",
                      _date('requestedDate', 'Not provided'),
                    ),
                    _ReceiptRow(
                      "Claiming date",
                      _date('claimDate', _claimFallback),
                      strong: true,
                    ),
                  ] else ...[
                    _ReceiptRow(
                      "Requested date",
                      _date('requestedDate', 'Not provided'),
                    ),
                    _ReceiptRow(
                      "Final date",
                      _date('finalDate', _hearingFallback),
                      strong: true,
                    ),
                  ],
                ],
                if (isRequest && fee != null) ...[
                  const _DashedLine(),
                  const _SectionLabel("Fee"),
                  _ReceiptRow("Document fee", fee),
                  _ReceiptRow("Payment", switch (status) {
                    'Rejected' => 'No payment due',
                    'Resolved' => 'See official receipt',
                    _ when fee == 'Free' => 'No payment needed',
                    _ => 'Pay when claiming',
                  }),
                  if (status != 'Resolved') ...[
                    const SizedBox(height: AppSpace.s1),
                    Divider(height: AppSpace.s3, color: c.ink),
                    _ReceiptRow(
                      "AMOUNT DUE",
                      status == 'Rejected' || fee == 'Free' ? 'PHP 0.00' : fee,
                      total: true,
                    ),
                  ],
                ],
                const _DashedLine(),
                Text(
                  _footer,
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: c.inkMuted),
                ),
                if (isRequest) ...[
                  const SizedBox(height: AppSpace.s2),
                  Text(
                    "Fees follow the barangay ordinance and may change.",
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(color: c.inkMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.s2),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: context.colors.primary,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    ),
  );
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow(
    this.label,
    this.value, {
    this.strong = false,
    this.total = false,
  });

  final String label;
  final String value;
  final bool strong;
  final bool total;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final valueStyle = total ? text.titleLarge : text.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: total
                  ? text.titleMedium
                  : text.bodySmall?.copyWith(color: c.inkMuted),
            ),
          ),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: valueStyle?.copyWith(
                fontWeight: strong || total ? FontWeight.w600 : null,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpace.s3),
    child: CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _DashPainter(context.colors.inkMuted),
    ),
  );
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 8) {
      final end = x + 4 > size.width ? size.width : x + 4;
      canvas.drawLine(Offset(x, 0.5), Offset(end, 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// Rounded top with a saw-tooth bottom, like paper torn from a printer.
class _TornEdgeClipper extends CustomClipper<Path> {
  const _TornEdgeClipper();

  static const _radius = 12.0;
  static const _toothWidth = 14.0;
  static const _toothHeight = 7.0;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final teeth = (w / _toothWidth).floor().clamp(1, 1000);
    final step = w / teeth;

    final path = Path()
      ..moveTo(0, _radius)
      ..quadraticBezierTo(0, 0, _radius, 0)
      ..lineTo(w - _radius, 0)
      ..quadraticBezierTo(w, 0, w, _radius)
      ..lineTo(w, h - _toothHeight);
    for (var i = 0; i < teeth; i++) {
      final x = w - step * i;
      path
        ..lineTo(x - step / 2, h)
        ..lineTo(x - step, h - _toothHeight);
    }
    return path..close();
  }

  @override
  bool shouldReclip(_TornEdgeClipper oldClipper) => false;
}
