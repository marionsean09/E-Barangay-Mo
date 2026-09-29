import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:e_barangay_mo/theme/phosphor_icons.dart';
import 'package:e_barangay_mo/services/api_service.dart';
import 'package:e_barangay_mo/resident/request_options.dart';
import 'package:e_barangay_mo/theme/app_colors.dart';
import 'package:e_barangay_mo/theme/app_tokens.dart';
import 'package:e_barangay_mo/utils/concern_format.dart';
import 'package:e_barangay_mo/widgets/app_card.dart';
import 'package:e_barangay_mo/widgets/press_scale.dart';

class SubmitConcernPage extends StatefulWidget {
  const SubmitConcernPage({super.key, this.initialType = 'Complaint'});

  final String initialType;

  @override
  State<SubmitConcernPage> createState() => _SubmitConcernPageState();
}

class _SubmitConcernPageState extends State<SubmitConcernPage> {
  final title = TextEditingController();
  final description = TextEditingController();
  final purpose = TextEditingController();
  late String type = widget.initialType;
  String requestType = requestFees.keys.first;

  final picker = ImagePicker();
  final Map<String, XFile> requirementFiles = {};
  final Map<String, Uint8List> requirementPreviews = {};
  bool isSubmitting = false;

  String blotterCategory = blotterCategories.first;
  DateTime? requestedDate;
  final List<Uint8List> blotterPhotos = [];

  bool get isRequest => type == "Request";
  bool get isBlotter => type == "Blotter";

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String imageExtension(Uint8List bytes) {
    bool starts(List<int> sig, [int offset = 0]) =>
        bytes.length >= offset + sig.length &&
        List.generate(
          sig.length,
          (i) => bytes[offset + i] == sig[i],
        ).every((same) => same);

    if (starts([0xFF, 0xD8, 0xFF])) return 'jpg';
    if (starts([0x89, 0x50, 0x4E, 0x47])) return 'png';
    if (starts([0x52, 0x49, 0x46, 0x46]) &&
        starts([0x57, 0x45, 0x42, 0x50], 8)) {
      return 'webp';
    }
    if (starts([0x47, 0x49, 0x46, 0x38])) return 'gif';
    if (starts([0x66, 0x74, 0x79, 0x70], 4)) return 'heic';
    return 'unknown';
  }

  static const acceptedExtensions = {'jpg', 'png', 'webp'};

  Future<void> pickRequirement(String key) async {
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!acceptedExtensions.contains(imageExtension(bytes))) {
      showMessage("Please choose a JPG, PNG or WEBP photo.");
      return;
    }
    setState(() {
      requirementFiles[key] = picked;
      requirementPreviews[key] = bytes;
    });
  }

  Future<void> addBlotterPhoto() async {
    if (blotterPhotos.length >= maxBlotterPhotos) return;
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!acceptedExtensions.contains(imageExtension(bytes))) {
      showMessage("Please choose a JPG, PNG or WEBP photo.");
      return;
    }
    setState(() => blotterPhotos.add(bytes));
  }

  Future<void> pickRequestedDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    var first = today.add(const Duration(days: 1));
    while (first.weekday > DateTime.friday) {
      first = first.add(const Duration(days: 1));
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: requestedDate ?? first,
      firstDate: first,
      lastDate: today.add(const Duration(days: 90)),
      helpText: "Requested date",
      confirmText: "Choose",
      selectableDayPredicate: (day) => day.weekday <= DateTime.friday,
    );
    if (picked != null) setState(() => requestedDate = picked);
  }

  UploadFile photoFile(Uint8List bytes, String name) =>
      (bytes: bytes, filename: '$name.${imageExtension(bytes)}');

  // The checks below give quick feedback; the server validates everything
  // again (types, lengths, dates, real image bytes) before saving.
  void submit() async {
    if (isRequest) {
      final missing = requirementLabels.keys
          .where((key) => !requirementPreviews.containsKey(key))
          .map((key) => requirementLabels[key]);
      if (missing.isNotEmpty) {
        showMessage("Please upload: ${missing.join(', ')}");
        return;
      }
      if (purpose.text.trim().isEmpty) {
        showMessage("Please enter the purpose of your request");
        return;
      }
    } else if (isBlotter) {
      if (description.text.trim().isEmpty) {
        showMessage("Please write the reason for the blotter report");
        return;
      }
      if (requestedDate == null) {
        showMessage("Please choose your requested date");
        return;
      }
    } else {
      if (title.text.trim().isEmpty || description.text.trim().isEmpty) {
        showMessage("Please fill in the title and description");
        return;
      }
    }

    setState(() => isSubmitting = true);

    try {
      // One multipart request: the server saves the concern and its
      // photos in a single transaction. The owner and status are set by the
      // server, not sent from here.
      await ApiService.submitConcern(
        fields: {
          'type': type,
          if (isRequest) ...{
            'request_type': requestType,
            'purpose': purpose.text.trim(),
          } else if (isBlotter) ...{
            'blotter_category': blotterCategory,
            'description': description.text.trim(),
            'requested_date': apiDate(requestedDate!),
          } else ...{
            'title': title.text.trim(),
            'description': description.text.trim(),
          },
        },
        files: {
          if (isRequest)
            for (final key in requirementLabels.keys)
              key: photoFile(requirementPreviews[key]!, key),
        },
        evidence: [
          if (isBlotter)
            for (var i = 0; i < blotterPhotos.length; i++)
              photoFile(blotterPhotos[i], 'blotter-${i + 1}'),
        ],
      );

      if (!mounted) return;
      showMessage(
        isRequest
            ? "Request sent. We'll post your claiming date here."
            : isBlotter
            ? "Blotter report sent. The barangay will confirm your date."
            : "Report sent to the barangay.",
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      showMessage(e.message);
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Widget requirementTile(String key) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final preview = requirementPreviews[key];
    final done = preview != null;
    final radius = BorderRadius.circular(AppRadius.sm);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s3),
      child: Material(
        color: c.surfaceRaised,
        borderRadius: radius,
        child: InkWell(
          onTap: isSubmitting ? null : () => pickRequirement(key),
          borderRadius: radius,
          child: Container(
            padding: const EdgeInsets.all(AppSpace.s3),
            decoration: BoxDecoration(
              border: Border.all(color: done ? c.success : c.inkMuted),
              borderRadius: radius,
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: radius,
                  child: done
                      ? Image.memory(
                          preview,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 56,
                          height: 56,
                          color: c.primarySoft,
                          child: Icon(
                            PhosphorIconsRegular.camera,
                            color: c.primary,
                          ),
                        ),
                ),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(requirementLabels[key]!, style: text.titleMedium),
                      Text(
                        done
                            ? "Uploaded. Tap to change."
                            : "Tap to upload a photo",
                        style: text.bodySmall?.copyWith(
                          color: done ? c.success : c.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  done
                      ? PhosphorIconsRegular.checkCircle
                      : PhosphorIconsRegular.uploadSimple,
                  color: done ? c.success : c.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget feeNotice() {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.s4),
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIconsRegular.info, color: c.primary, size: 20),
              const SizedBox(width: AppSpace.s2),
              Text(
                "Notice of fee",
                style: text.titleMedium?.copyWith(color: c.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s2),
          Text(
            "$requestType: ${requestFees[requestType]}",
            style: text.titleLarge?.copyWith(color: c.primary),
          ),
          const SizedBox(height: AppSpace.s2),
          Text(
            "• Pay the fee at the Barangay Treasurer's Office when you claim your document.\n"
            "• Bring the original copies of your valid ID and Cedula for verification.\n"
            "• An official receipt is issued for every payment. Fees follow the barangay ordinance and may change.",
            style: text.bodyMedium?.copyWith(color: c.primary),
          ),
        ],
      ),
    );
  }

  List<Widget> blotterFields() {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final date = requestedDate;

    return [
      DropdownButtonFormField(
        initialValue: blotterCategory,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: "What happened",
          prefixIcon: Icon(PhosphorIconsRegular.scales),
        ),
        items: blotterCategories
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) => setState(() => blotterCategory = v!),
      ),
      const SizedBox(height: AppSpace.s4),
      TextField(
        controller: description,
        maxLines: 5,
        decoration: const InputDecoration(
          labelText: "Reason for the blotter report",
          hintText: "What happened, when and where, and who was involved",
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: AppSpace.s4),
      InkWell(
        onTap: isSubmitting ? null : pickRequestedDate,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: "Requested date",
            helperText: "The barangay will confirm this date or set another one.",
            prefixIcon: Icon(PhosphorIconsRegular.calendarBlank),
          ),
          child: Text(
            date == null ? "Choose a weekday" : formatLongDate(date),
            style: text.bodyLarge?.copyWith(
              color: date == null ? c.inkMuted : c.ink,
            ),
          ),
        ),
      ),
      const SizedBox(height: AppSpace.s6),
      Text("Photos (optional)", style: text.titleMedium),
      const SizedBox(height: AppSpace.s1),
      Text(
        "Up to $maxBlotterPhotos, for example damage, injuries or the place it happened.",
        style: text.bodySmall,
      ),
      const SizedBox(height: AppSpace.s3),
      Wrap(
        spacing: AppSpace.s3,
        runSpacing: AppSpace.s3,
        children: [
          for (var i = 0; i < blotterPhotos.length; i++)
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Image.memory(
                    blotterPhotos[i],
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: -8,
                  right: -8,
                  child: Material(
                    color: c.ink,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: isSubmitting
                          ? null
                          : () => setState(() => blotterPhotos.removeAt(i)),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.s1),
                        child: Icon(
                          PhosphorIconsRegular.x,
                          size: 16,
                          color: c.surface,
                          semanticLabel: "Remove photo",
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          if (blotterPhotos.length < maxBlotterPhotos)
            InkWell(
              onTap: isSubmitting ? null : addBlotterPhoto,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(PhosphorIconsRegular.plus, color: c.primary),
                    const SizedBox(height: AppSpace.s1),
                    Text(
                      "Add photo",
                      style: text.labelMedium?.copyWith(color: c.primary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: AppSpace.s6),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.s4),
        decoration: BoxDecoration(
          color: c.primarySoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(PhosphorIconsRegular.info, color: c.primary, size: 20),
                const SizedBox(width: AppSpace.s2),
                Text(
                  "What happens next",
                  style: text.titleMedium?.copyWith(color: c.primary),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s2),
            Text(
              "• The barangay reviews your report and confirms your requested date, or sets another one.\n"
              "• The final date shows on your home screen.\n"
              "• Come to the barangay hall on that date and bring a valid ID.",
              style: text.bodyMedium?.copyWith(color: c.primary),
            ),
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isRequest
              ? "Request a document"
              : isBlotter
              ? "File a blotter report"
              : "Report a concern",
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpace.s6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Concern details", style: text.titleLarge),
                  const SizedBox(height: AppSpace.s1),
                  Text(
                    "Tell the barangay what you need. Updates show on your home screen.",
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: AppSpace.s6),

                  DropdownButtonFormField(
                    initialValue: type,
                    decoration: const InputDecoration(
                      labelText: "Concern type",
                      prefixIcon: Icon(PhosphorIconsRegular.squaresFour),
                    ),
                    items: ["Complaint", "Request", "Suggestion", "Blotter"]
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e == "Blotter" ? "Blotter report" : e),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => type = v!),
                  ),
                  const SizedBox(height: AppSpace.s4),

                  if (isBlotter) ...blotterFields(),

                  if (!isRequest && !isBlotter) ...[
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(
                        labelText: "Title",
                        prefixIcon: Icon(PhosphorIconsRegular.textT),
                      ),
                    ),
                    const SizedBox(height: AppSpace.s4),
                    TextField(
                      controller: description,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: "Description",
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],

                  if (isRequest) ...[
                    DropdownButtonFormField(
                      initialValue: requestType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: "Document requested",
                        prefixIcon: Icon(PhosphorIconsRegular.fileText),
                      ),
                      items: requestFees.keys
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => requestType = v!),
                    ),
                    const SizedBox(height: AppSpace.s6),

                    Text("General requirements", style: text.titleMedium),
                    const SizedBox(height: AppSpace.s1),
                    Text(
                      "Clear photos, all four corners visible.",
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: AppSpace.s3),
                    for (final key in requirementLabels.keys)
                      requirementTile(key),
                    const SizedBox(height: AppSpace.s3),

                    TextField(
                      controller: purpose,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Purpose of request",
                        hintText:
                            "e.g. Employment, school requirement, bank account",
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s6),

                    feeNotice(),
                  ],

                  const SizedBox(height: AppSpace.s6),

                  SizedBox(
                    width: double.infinity,
                    child: PressScale(
                      enabled: !isSubmitting,
                      child: ElevatedButton.icon(
                        icon: isSubmitting
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: c.onPrimary,
                                ),
                              )
                            : const Icon(PhosphorIconsRegular.paperPlaneTilt),
                        label: Text(isSubmitting ? "Submitting" : "Submit"),
                        onPressed: isSubmitting ? null : submit,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
