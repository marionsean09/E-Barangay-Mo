import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:e_barangay_mo/core/services/api_service.dart';
import 'package:e_barangay_mo/core/theme/app_colors.dart';
import 'package:e_barangay_mo/core/theme/app_tokens.dart';
import 'package:e_barangay_mo/core/theme/phosphor_icons.dart';

/// Responsive grid of a concern's uploaded photos (label + attachment id).
class ConcernPhotoGrid extends StatelessWidget {
  const ConcernPhotoGrid({super.key, required this.photos});

  final List<(String, int?)> photos;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 480 ? 2 : 4;
        final width =
            (constraints.maxWidth - AppSpace.s3 * (columns - 1)) / columns;
        return Wrap(
          spacing: AppSpace.s3,
          runSpacing: AppSpace.s3,
          children: [
            for (final (label, fileId) in photos)
              SizedBox(
                width: width,
                child: ConcernPhoto(label: label, fileId: fileId),
              ),
          ],
        );
      },
    );
  }
}

class ConcernPhoto extends StatefulWidget {
  const ConcernPhoto({super.key, required this.label, required this.fileId});

  final String label;
  final int? fileId;

  @override
  State<ConcernPhoto> createState() => _ConcernPhotoState();
}

class _ConcernPhotoState extends State<ConcernPhoto> {
  Future<Uint8List>? bytes;

  bool get hasFile => widget.fileId != null;

  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    if (!hasFile) return;
    setState(() {
      // Streamed through the API, which checks the viewer is the owner
      // or an admin, decrypts the file and verifies its checksum.
      bytes = ApiService.attachment(widget.fileId!).catchError((Object e) {
        debugPrint('Requirement photo ${widget.fileId} failed: $e');
        throw e;
      });
    });
  }

  String reason(Object? error) {
    if (error is ApiException) {
      if (error.statusCode == 403) return "You don't have access to this file.";
      if (error.statusCode == 404) return "Photo not found.";
      return error.message;
    }
    return "Could not load. Check the connection.";
  }

  void openFull(Uint8List data) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: InteractiveViewer(child: Image.memory(data)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    Widget placeholder(IconData icon, String message) => Container(
          color: c.surface,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(AppSpace.s2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: c.inkMuted),
              const SizedBox(height: AppSpace.s1),
              Text(message,
                  style: text.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: !hasFile || bytes == null
                ? placeholder(PhosphorIconsRegular.imageBroken, "Not uploaded")
                : FutureBuilder<Uint8List>(
                    future: bytes,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return InkWell(
                          onTap: load,
                          child: placeholder(
                            PhosphorIconsRegular.warning,
                            "${reason(snapshot.error)} Tap to retry.",
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return Container(color: c.border);
                      }
                      return InkWell(
                        onTap: () => openFull(snapshot.data!),
                        child: Image.memory(
                          snapshot.data!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => placeholder(
                            PhosphorIconsRegular.imageBroken,
                            "Can't show this format. Ask for a JPG or PNG.",
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: AppSpace.s2),
        Text(widget.label, style: text.bodySmall),
      ],
    );
  }
}
