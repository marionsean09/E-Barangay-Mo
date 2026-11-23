import 'dart:async';

import 'package:flutter/material.dart';

import 'package:e_barangay_mo/core/models/concern.dart';
import 'package:e_barangay_mo/core/models/reply_notification.dart';
import 'package:e_barangay_mo/core/services/api_service.dart';
import 'package:e_barangay_mo/core/services/browser_alerts_io.dart'
    if (dart.library.js_interop) 'package:e_barangay_mo/core/services/browser_alerts_web.dart';
import 'package:e_barangay_mo/core/theme/app_tokens.dart';
import 'package:e_barangay_mo/core/utils/concern_format.dart';
import 'package:e_barangay_mo/core/widgets/concern_thread.dart';

/// App bar bell: unread complaint replies, with an alert when a new one arrives.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, required this.onOpen});

  /// Opens the complaint's page. Completes when the user comes back.
  final Future<void> Function(Concern concern) onOpen;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  List<ReplyNotification> items = [];
  Timer? poller;
  int? newestSeenId;

  int get unread => items.fold(0, (total, item) => total + item.unread);

  @override
  void initState() {
    super.initState();
    refresh();
    poller = Timer.periodic(const Duration(seconds: 15), (_) => refresh());
  }

  @override
  void dispose() {
    poller?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    try {
      final result = await ApiService.replyNotifications();
      if (!mounted) return;
      final previous = newestSeenId;
      final newest = result.isEmpty
          ? previous
          : result
              .map((n) => n.latestMessageId)
              .reduce((a, b) => a > b ? a : b);

      setState(() {
        items = result;
        // The first load sets the baseline, so old replies don't pop up.
        newestSeenId = (previous == null || (newest ?? 0) > previous)
            ? (newest ?? 0)
            : previous;
      });

      if (previous == null) return;
      _alert(result.where((n) {
        final isNew = n.latestMessageId > previous;
        final isBeingRead =
            ConcernThread.openConcernId == n.concern.id && !appIsHidden;
        return isNew && !isBeingRead;
      }).toList());
    } on ApiException {
      // A missed check is retried on the next one.
    }
  }

  void _alert(List<ReplyNotification> fresh) {
    if (fresh.isEmpty) return;
    final single = fresh.length == 1 ? fresh.first : null;
    final message = single == null
        ? "New replies on ${fresh.length} complaints"
        : "New reply on ${single.concern.data['title'] ?? 'your complaint'}";

    void open() => single == null ? _showList() : _open(single.concern);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        action: SnackBarAction(label: "View", onPressed: open),
      ));

    if (appIsHidden) {
      // No message text here: these can appear on a shared or locked screen.
      showBrowserAlert(
        title: "eBarangay Mo",
        body: single == null
            ? "You have new replies on ${fresh.length} complaints."
            : "New reply on Ref. ${referenceFor(single.concern)}",
        tag: "reply-${fresh.first.latestMessageId}",
        onTap: () {
          if (mounted) open();
        },
      );
    }
  }

  Future<void> _open(Concern concern) async {
    await widget.onOpen(concern);
    if (mounted) refresh();
  }

  Future<void> _enableAlerts(BuildContext sheetContext) async {
    final messenger = ScaffoldMessenger.of(context);
    final allowed = await requestBrowserAlerts();
    if (sheetContext.mounted) Navigator.pop(sheetContext);
    messenger.showSnackBar(SnackBar(
      content: Text(allowed
          ? "Browser alerts are on."
          : "Browser alerts are blocked. You can allow them in the site settings."),
    ));
  }

  void _showList() {
    final text = Theme.of(context).textTheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpace.s4),
                child: Text("Notifications", style: text.titleLarge),
              ),
              if (browserAlertsSupported &&
                  browserAlertPermission == 'default')
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text("Turn on browser alerts"),
                  subtitle: const Text("Get alerted while this tab is in the background."),
                  onTap: () => _enableAlerts(sheetContext),
                ),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.s4, 0, AppSpace.s4, AppSpace.s6),
                  child: Text("No new replies.", style: text.bodyMedium),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i];
                      return ListTile(
                        title: Text(item.concern.data['title'] ?? 'Complaint',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text("${item.senderName}: ${item.preview}",
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: Badge.count(count: item.unread),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _open(item.concern);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = unread;
    return IconButton(
      tooltip: count == 0 ? "Notifications" : "$count unread replies",
      onPressed: _showList,
      icon: Badge.count(
        count: count,
        isLabelVisible: count > 0,
        child: const Icon(Icons.notifications_none),
      ),
    );
  }
}
