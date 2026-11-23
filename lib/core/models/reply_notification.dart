import 'package:e_barangay_mo/core/models/concern.dart';

/// A complaint with replies the current user hasn't read.
class ReplyNotification {
  const ReplyNotification({
    required this.concern,
    required this.unread,
    required this.latestMessageId,
    required this.senderName,
    required this.preview,
  });

  final Concern concern;
  final int unread;
  final int latestMessageId;
  final String senderName;
  final String preview;

  factory ReplyNotification.fromJson(Map<String, dynamic> json) =>
      ReplyNotification(
        concern: Concern.fromJson(json['concern'] as Map<String, dynamic>),
        unread: json['unread'] as int,
        latestMessageId: json['latestMessageId'] as int,
        senderName: json['senderName'] as String,
        preview: json['preview'] as String,
      );
}
