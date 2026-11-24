import 'package:e_barangay_mo/core/models/concern.dart';

/// An unread complaint reply or, for admins, a new request or report.
class ReplyNotification {
  const ReplyNotification({
    required this.key,
    required this.kind,
    required this.heading,
    required this.concern,
    required this.unread,
    required this.senderName,
    required this.preview,
  });

  /// Identifies this event, so each one alerts only once.
  final String key;

  /// 'reply' or 'new'.
  final String kind;
  final String heading;
  final Concern concern;
  final int unread;
  final String senderName;
  final String preview;

  bool get isNewSubmission => kind == 'new';

  factory ReplyNotification.fromJson(Map<String, dynamic> json) =>
      ReplyNotification(
        key: json['key'] as String,
        kind: json['kind'] as String,
        heading: json['heading'] as String,
        concern: Concern.fromJson(json['concern'] as Map<String, dynamic>),
        unread: json['unread'] as int,
        senderName: json['senderName'] as String,
        preview: json['preview'] as String,
      );
}
