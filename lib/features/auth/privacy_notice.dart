import 'package:flutter/material.dart';

import 'package:e_barangay_mo/core/theme/app_tokens.dart';

const _sections = [
  (
    "What we collect",
    "Your name, email address, the concerns you file, and the documents you "
        "upload: valid ID (front and back), proof of address, cedula, and "
        "blotter evidence photos. We do not ask for your birth date, TIN or "
        "phone number.",
  ),
  (
    "Why we collect it",
    "To process your barangay requests and reports, based on your consent "
        "and the barangay's public function of issuing clearances and "
        "recording blotters (Data Privacy Act of 2012, RA 10173, sections 12 "
        "and 13).",
  ),
  (
    "Who is responsible",
    "The barangay is the personal information controller. Railway, which "
        "hosts this system, and Resend, which delivers verification emails, "
        "are personal information processors.",
  ),
  (
    "Where your data is stored",
    "Your data is hosted in Singapore, outside the Philippines. Your email "
        "address and verification code may also be processed abroad to deliver "
        "your email. The barangay remains accountable for this data under "
        "section 21 of the Act.",
  ),
  (
    "How we protect it",
    "Uploaded files and sensitive text are encrypted. Only you and authorized "
        "barangay staff can open your files, and access is recorded in an "
        "audit log.",
  ),
  (
    "How long we keep it",
    "Uploaded files are deleted one year after your concern is closed.",
  ),
  (
    "Your rights",
    "You can see every concern you filed and correct your profile in this "
        "app. For other privacy requests, please go to the barangay hall.",
  ),
  (
    "If there is a breach",
    "The barangay will notify the National Privacy Commission and affected "
        "residents within 72 hours of discovery.",
  ),
];

Future<void> showPrivacyNotice(BuildContext context) {
  final text = Theme.of(context).textTheme;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Privacy notice"),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (heading, body) in _sections) ...[
                Text(heading, style: text.titleMedium),
                const SizedBox(height: AppSpace.s1),
                Text(body, style: text.bodyMedium),
                const SizedBox(height: AppSpace.s4),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text("Close"),
        ),
      ],
    ),
  );
}
