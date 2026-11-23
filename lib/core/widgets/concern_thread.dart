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
class ConcernThread extends StatefulWidget {
  const ConcernThread({super.key, required this.concernId});

  final int concernId;

  /// The thread on screen, so the bell doesn't alert about what's being read.
  static int? openConcernId;

  @override
  State<ConcernThread> createState() => _ConcernThreadState();
}

class _ConcernThreadState extends State<ConcernThread> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<ConcernMessage> messages = [];
  bool isLoading = true;
  bool isSending = false;
  String? loadError;
  Timer? poller;
  int _markedReadId = 0;

  @override
  void initState() {
    super.initState();
    ConcernThread.openConcernId = widget.concernId;
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
    _scroll.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final result = await ApiService.concernMessages(widget.concernId);
      if (!mounted) return;
      final hasNew = result.isNotEmpty &&
          (messages.isEmpty || result.last.id != messages.last.id);
      setState(() {
        messages = result;
        isLoading = false;
        loadError = null;
      });
      if (hasNew) _scrollToEnd();
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

  /// Replies count as read only while this tab is actually visible.
  Future<void> _markRead() async {
    if (appIsHidden) return;
    final theirs = messages.where((m) => !m.isMine);
    if (theirs.isEmpty || theirs.last.id <= _markedReadId) return;
    final previous = _markedReadId;
    _markedReadId = theirs.last.id;
    try {
      await ApiService.markMessagesRead(widget.concernId, _markedReadId);
    } on ApiException {
      _markedReadId = previous; // Retried on the next refresh.
    }
  }

  Future<void> send() async {
    final body = _input.text.trim();
    if (body.isEmpty || isSending) return;
    setState(() => isSending = true);
    try {
      final sent =
          await ApiService.sendConcernMessage(widget.concernId, body);
      if (!mounted) return;
      _input.clear();
      setState(() {
        if (!messages.any((m) => m.id == sent.id)) {
          messages = [...messages, sent];
        }
        loadError = null;
      });
      _scrollToEnd();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.colors;

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Conversation", style: text.titleMedium),
          const SizedBox(height: AppSpace.s3),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpace.s4),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (loadError != null)
            Row(
              children: [
                Expanded(
                  child: Text(loadError!,
                      style: text.bodyMedium?.copyWith(color: c.danger)),
                ),
                TextButton(onPressed: load, child: const Text("Retry")),
              ],
            )
          else if (messages.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s3),
              child: Text("No replies yet. Start the conversation below.",
                  style: text.bodySmall),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: ListView.separated(
                controller: _scroll,
                shrinkWrap: true,
                itemCount: messages.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpace.s3),
                itemBuilder: (_, i) => _Bubble(message: messages[i]),
              ),
            ),
          const SizedBox(height: AppSpace.s4),
          Row(
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
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ConcernMessage message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final mine = message.isMine;
    final foreground = mine ? c.onPrimary : c.ink;
    final sent = parseDate(message.createdAt);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(mine ? "You" : message.senderName, style: text.labelMedium),
            const SizedBox(height: AppSpace.s1),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s3, vertical: AppSpace.s2),
              decoration: BoxDecoration(
                color: mine ? c.primary : c.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: SelectableText(message.body,
                  style: text.bodyMedium?.copyWith(color: foreground)),
            ),
            if (sent != null) ...[
              const SizedBox(height: AppSpace.s1),
              Text(formatDateTime(sent), style: text.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
