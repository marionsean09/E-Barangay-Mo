import 'package:flutter/widgets.dart';
import 'package:e_barangay_mo/core/models/concern.dart';
import 'package:e_barangay_mo/core/theme/phosphor_icons.dart';

const readyForPickup = 'Ready for Pickup';

const concernStatuses = [
  'Pending',
  readyForPickup,
  'Resolved',
  'Rejected',
];

/// Statuses an admin can set. Ready for Pickup is for document requests only.
List<String> statusesFor(String? type) => type == 'Request'
    ? concernStatuses
    : concernStatuses.where((s) => s != readyForPickup).toList();

/// Resolved and rejected concerns are final. The server enforces this too.
bool isClosedStatus(String? status) =>
    status == 'Resolved' || status == 'Rejected';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const _referencePrefixes = {
  'Barangay Clearance': 'BC',
  'Certificate of Residency': 'CR',
  'Certificate of Indigency': 'CI',
  'Barangay Business Permit / Clearance': 'BP',
  'Certificate to File Action': 'FA',
  'Complaint': 'CP',
  'Suggestion': 'SG',
  'Blotter': 'BL',
};

DateTime? parseDate(String? iso) =>
    iso == null ? null : DateTime.tryParse(iso)?.toLocal();

String formatDate(DateTime date) =>
    '${_months[date.month - 1]} ${date.day}, ${date.year}';

String formatLongDate(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${formatDate(date)}';

String formatDateTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '${formatDate(date)}, $hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
}

/// Calendar date in the format the API expects: yyyy-MM-dd.
String apiDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String referenceFor(Concern row) {
  final data = row.data;
  final key = data['type'] == 'Request' ? data['requestType'] : data['type'];
  final prefix = _referencePrefixes[key] ?? 'EB';
  final year = parseDate(row.createdAt)?.year ?? DateTime.now().year;
  return '$prefix-$year-${row.id.toString().padLeft(4, '0')}';
}

String statusLabel(Map<String, dynamic> data) {
  final String status = data['status'] ?? 'Pending';
  if (data['type'] == 'Blotter') {
    if (status == 'Pending' && data['finalDate'] != null) return 'Scheduled';
    if (status == 'Resolved') return 'Settled';
  }
  return status;
}

IconData typeIcon(String? type) => switch (type) {
      'Request' => PhosphorIconsRegular.fileText,
      'Suggestion' => PhosphorIconsRegular.lightbulb,
      'Blotter' => PhosphorIconsRegular.scales,
      _ => PhosphorIconsRegular.megaphone,
    };

String greeting([DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

String firstName(String fullName) {
  final trimmed = fullName.trim();
  return trimmed.isEmpty ? '' : trimmed.split(RegExp(r'\s+')).first;
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}
