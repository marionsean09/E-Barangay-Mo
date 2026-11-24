import 'package:flutter/material.dart';

import 'package:e_barangay_mo/core/models/concern.dart';
import 'package:e_barangay_mo/core/theme/app_tokens.dart';
import 'package:e_barangay_mo/core/utils/concern_format.dart';
import 'package:e_barangay_mo/core/widgets/app_card.dart';
import 'package:e_barangay_mo/core/widgets/concern_photos.dart';
import 'package:e_barangay_mo/core/widgets/concern_receipt.dart';
import 'package:e_barangay_mo/core/widgets/concern_thread.dart';
import 'package:e_barangay_mo/core/widgets/status_pill.dart';
import 'package:e_barangay_mo/features/resident/request_options.dart';

/// Everything a resident submitted for one service, read-only. Complaints
/// also show the conversation with the barangay.
class ConcernDetailsPage extends StatelessWidget {
  const ConcernDetailsPage({super.key, required this.row});

  final Concern row;

  Map<String, dynamic> get data => row.data;
  bool get isRequest => data['type'] == 'Request';
  bool get isBlotter => data['type'] == 'Blotter';
  bool get isComplaint => data['type'] == 'Complaint';

  List<(String, int?)> get photos {
    if (isRequest) {
      return [
        for (final entry in requirementLabels.entries)
          (entry.value, data[entry.key] as int?),
      ];
    }
    final evidence = (data['evidence'] as List?)?.cast<int>() ?? [];
    return [
      for (var i = 0; i < evidence.length; i++) ("Photo ${i + 1}", evidence[i]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text("Ref. ${referenceFor(row)}")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpace.s2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        data['title'] ?? '',
                        style: text.headlineMedium,
                      ),
                    ),
                    const SizedBox(width: AppSpace.s3),
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.s2),
                      child: StatusPill(
                        data['status'] ?? 'Pending',
                        label: statusLabel(data),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s6),
                ConcernReceipt(concern: row),
                const SizedBox(height: AppSpace.s4),
                AppCard(
                  padding: const EdgeInsets.all(AppSpace.s6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRequest
                            ? "Purpose"
                            : isBlotter
                            ? "Reason"
                            : "Details",
                        style: text.titleMedium,
                      ),
                      const SizedBox(height: AppSpace.s2),
                      Text(
                        (isRequest ? data['purpose'] : data['description']) ??
                            '',
                        style: text.bodyLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.s4),
                if (isRequest || isBlotter) ...[
                  AppCard(
                    padding: const EdgeInsets.all(AppSpace.s6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRequest ? "Requirements" : "Photos",
                          style: text.titleMedium,
                        ),
                        const SizedBox(height: AppSpace.s4),
                        if (photos.isEmpty)
                          Text("No photos attached.", style: text.bodySmall)
                        else
                          ConcernPhotoGrid(photos: photos),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.s4),
                ],
                if (isComplaint) ...[
                  ConcernThread(
                    concernId: row.id,
                    readOnly: isClosedStatus(data['status']),
                  ),
                  const SizedBox(height: AppSpace.s4),
                ],
                const SizedBox(height: AppSpace.s4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
