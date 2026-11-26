import 'dart:async';

import 'package:flutter/material.dart';

import 'package:e_barangay_mo/core/models/concern_message.dart';
import 'package:e_barangay_mo/core/services/api_service.dart';
import 'package:e_barangay_mo/core/services/browser_alerts_io.dart'
    if (dart.library.js_interop) 'package:e_barangay_mo/core/services/browser_alerts_web.dart';
import 'package:e_barangay_mo/core/theme/app_colors.dart';
import 'package:e_barangay_mo/core/theme/app_tokens.dart';
import 'package:e_barangay_mo/core/theme/phosphor_icons.dart';
import 'package:e_barangay_mo/core/utils/concern_format.dart';
import 'package:e_barangay_mo/core/widgets/app_card.dart';

/// The reply thread on a complaint, shared by the resident and admin screens.
///
/// Collapsed by default to one clickable row (title, reply count, unread dot,
/// preview of the latest reply). Opened, it shows the latest replies as
/// comments, with "View earlier replies" for the rest.
class ConcernThread extends StatefulWidget {
  const ConcernThread({
    super.key,
    required this.concernId,
    this.readOnly = false,
  });

  final int concernId;

  /// Closed complaints keep their history but can't get new replies.
  final bool readOnly;

  /// The thread open on screen, so the bell doesn't alert about what's being read.
  static int? openConcernId;

  @override
  State<ConcernThread> createState() => _ConcernThreadState();
}

class _ConcernThreadState extends State<ConcernThread> {
  static const _recentCount = 3;

  final _input = TextEditingController();
  List<ConcernMessage> messages = [];
  bool isLoading = true;
  bool isSending = false;
  String? loadError;
  Timer? poller;
  int _markedReadId = 0;

  /// Collapsed to a one-line summary until the user opens it.
  bool expanded = false;

  /// Only the latest replies show until "View earlier replies" is tapped.
  bool showAll = false;

  bool get hasUnread {
    final theirs = messages.where((m) => !m.isMine);
    return theirs.isNotEmpty && theirs.last.id > _markedReadId;
  }

  void toggle() {
    setState(() => expanded = !expanded);
    // Only an open thread counts as "being read" (the bell stays quiet for it).
    if (expanded) {
      ConcernThread.openConcernId = widget.concernId;
      _markRead();
    } else if (ConcernThread.openConcernId == widget.concernId) {
      ConcernThread.openConcernId = null;
    }
  }

  @override
  void initState() {
    super.initState();
    load();
    // Picks up replies from the other side.
    poller = Timer.periodic(const Duration(seconds: 10), (_) => load());
  }

  @override
  void dispose() {
    if (ConcernThread.openConcernId == widget.concernId) {
      ConcernThread.openConcernId = null;
    }
    poller?.cancel();
    _input.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final result = await ApiService.concernMessages(widget.concernId);
      if (!mounted) return;
      setState(() {
        messages = result;
        isLoading = false;
        loadError = null;
      });
      await _markRead();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        // A failed background refresh shouldn't hide messages already shown.
        if (messages.isEmpty) loadError = e.message;
      });
    }
  }

  /// Replies count as read only once the thread is open and the tab visible.
  Future<void> _markRead() async {
    if (appIsHidden || !expanded) return;
    final theirs = messages.where((m) => !m.isMine);
    if (theirs.isEmpty || theirs.last.id <= _markedReadId) return;
    final previous = _markedReadId;
    setState(() => _markedReadId = theirs.last.id);
    try {
      await ApiService.markMessagesRead(widget.concernId, _markedReadId);
    } on ApiException {
      if (mounted) setState(() => _markedReadId = previous); // Retried on the next refresh.
    }
  }

  Future<void> send() async {
    final body = _input.text.trim();
    if (body.isEmpty || isSending) return;
    setState(() => isSending = true);
    try {
      final sent = await ApiService.sendConcernMessage(widget.concernId, body);
      if (!mounted) return;
      _input.clear();
      setState(() {
        if (!messages.any((m) => m.id == sent.id)) {
          messages = [...messages, sent];
        }
        loadError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.colors;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(text, c),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: !expanded
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpace.s4, 0, AppSpace.s4, AppSpace.s4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Divider(height: 1, color: c.border),
                        const SizedBox(height: AppSpace.s3),
                        ..._body(text, c),
                        const SizedBox(height: AppSpace.s3),
                        _composer(text),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// The always-visible row. Tap to open or close the thread.
  Widget _header(TextTheme text, AppColors c) {
    final last = messages.isEmpty ? null : messages.last;
    final count = messages.length;

    final String summary;
    if (isLoading) {
      summary = "Loading replies";
    } else if (loadError != null) {
      summary = loadError!;
    } else if (last == null) {
      summary = widget.readOnly ? "No replies were sent" : "No replies yet. Tap to reply.";
    } else {
      final who = last.isMine ? "You" : last.senderName;
      final when = parseDate(last.createdAt);
      final body = last.body.replaceAll('\n', ' ');
      summary = when == null ? "$who: $body" : "$who: $body · ${timeAgo(when)}";
    }

    return Semantics(
      button: true,
      expanded: expanded,
      child: InkWell(
        onTap: toggle,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Row(
            children: [
              Icon(Icons.forum_outlined, color: c.primary, size: 22),
              const SizedBox(width: AppSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text("Conversation", style: text.titleMedium),
                        if (count > 0) ...[
                          const SizedBox(width: AppSpace.s2),
                          Text(
                            "$count ${count == 1 ? 'reply' : 'replies'}",
                            style: text.bodySmall,
                          ),
                        ],
                        if (hasUnread && !expanded) ...[
                          const SizedBox(width: AppSpace.s2),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: c.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (!expanded) ...[
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: loadError != null ? c.danger : null,
                          fontWeight: hasUnread ? FontWeight.w600 : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.expand_more, color: c.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(TextTheme text, AppColors c) {
    if (isLoading) {
      return const [
        Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ];
    }
    if (loadError != null) {
      return [
        Row(
          children: [
            Expanded(
              child: Text(
                loadError!,
                style: text.bodyMedium?.copyWith(color: c.danger),
              ),
            ),
            TextButton(onPressed: load, child: const Text("Retry")),
          ],
        ),
      ];
    }
    if (messages.isEmpty) {
      return [
        Text(
          widget.readOnly
              ? "No replies were sent."
              : "No replies yet. Start the conversation below.",
          style: text.bodySmall,
        ),
      ];
    }

    final hidden = showAll ? 0 : messages.length - _recentCount;
    final shown = hidden > 0 ? messages.sublist(hidden) : messages;

    return [
      if (hidden > 0)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => setState(() => showAll = true),
            child: Text(
              "View $hidden earlier ${hidden == 1 ? 'reply' : 'replies'}",
            ),
          ),
        ),
      for (final m in shown) ...[
        _Comment(message: m),
        const SizedBox(height: AppSpace.s2),
      ],
    ];
  }

  Widget _composer(TextTheme text) {
    if (widget.readOnly) {
      return Text(
        "This complaint is closed. No more replies can be sent.",
        style: text.bodySmall,
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _input,
            enabled: !isSending,
            minLines: 1,
            maxLines: 4,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: "Write a reply",
              counterText: "",
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: AppSpace.s2),
        IconButton.filled(
          tooltip: "Send",
          icon: const Icon(PhosphorIconsRegular.paperPlaneTilt),
          onPressed: isSending ? null : send,
        ),
      ],
    );
  }
}

/// "just now", "5m ago", "3h ago", "2d ago", then the date.
String timeAgo(DateTime when, [DateTime? now]) {
  final diff = (now ?? DateTime.now()).difference(when);
  if (diff.inMinutes < 1) return "just now";
  if (diff.inHours < 1) return "${diff.inMinutes}m ago";
  if (diff.inDays < 1) return "${diff.inHours}h ago";
  if (diff.inDays < 7) return "${diff.inDays}d ago";
  return formatDate(when);
}

/// One reply, laid out like a comment: avatar, name and time, then the text.
class _Comment extends StatelessWidget {
  const _Comment({required this.message});

  final ConcernMessage message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final mine = message.isMine;
    final name = mine ? "You" : message.senderName;
    final sent = parseDate(message.createdAt);
    final trimmed = message.senderName.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.all(AppSpace.s3),
      decoration: BoxDecoration(
        color: mine ? c.primarySoft : c.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: mine ? c.primary : c.inkMuted,
            child: Text(
              initial,
              style: text.labelMedium?.copyWith(color: c.onPrimary),
            ),
          ),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: name,
                        style: text.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (sent != null)
                        TextSpan(
                          text: "  ·  ${timeAgo(sent)}",
                          style: text.bodySmall,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(message.body, style: text.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
