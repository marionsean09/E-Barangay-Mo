import 'package:flutter/material.dart';
import 'package:e_barangay_mo/theme/phosphor_icons.dart';

import 'package:e_barangay_mo/models/app_user.dart';
import 'package:e_barangay_mo/services/api_service.dart';
import 'package:e_barangay_mo/theme/app_colors.dart';
import 'package:e_barangay_mo/theme/app_tokens.dart';
import 'package:e_barangay_mo/utils/concern_format.dart';
import 'package:e_barangay_mo/widgets/app_card.dart';
import 'package:e_barangay_mo/widgets/press_scale.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.user});

  final AppUser user;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final fullName = TextEditingController(text: widget.user.name);
  late final email = TextEditingController(text: widget.user.email);
  final currentPassword = TextEditingController();
  final newPassword = TextEditingController();

  late AppUser user = widget.user;
  bool isSaving = false;
  String? error;

  @override
  void dispose() {
    fullName.dispose();
    email.dispose();
    currentPassword.dispose();
    newPassword.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final name = fullName.text.trim();
    final newEmail = email.text.trim();
    final emailChanged = newEmail != user.email;
    final passwordChanged = newPassword.text.isNotEmpty;

    if (name.isEmpty) {
      setState(() => error = "Enter your full name.");
      return;
    }
    if ((emailChanged || passwordChanged) && currentPassword.text.isEmpty) {
      setState(() => error =
          "Enter your current password to change your email or password.");
      return;
    }
    if (passwordChanged && newPassword.text.length < 8) {
      setState(() => error = "Your new password needs at least 8 characters.");
      return;
    }
    // The server re-checks all of this; these checks just give quick feedback.

    setState(() {
      isSaving = true;
      error = null;
    });

    try {
      user = await ApiService.updateProfile(
        fullName: name,
        email: newEmail,
        currentPassword: currentPassword.text,
        newPassword: newPassword.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Profile saved")));
      Navigator.pop(context, user);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Edit profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpace.s4),
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        initials(user.name.isNotEmpty ? user.name : user.email),
                        style: text.titleLarge?.copyWith(color: c.primary),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name.isNotEmpty ? user.name : "No name yet",
                              style: text.titleLarge),
                          Text(
                            "Member since ${formatDate(parseDate(user.createdAt) ?? DateTime.now())}",
                            style: text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s6),

                AppCard(
                  padding: const EdgeInsets.all(AppSpace.s6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Personal details", style: text.titleMedium),
                      const SizedBox(height: AppSpace.s4),
                      TextField(
                        controller: fullName,
                        decoration: const InputDecoration(
                          labelText: "Full name",
                          prefixIcon: Icon(PhosphorIconsRegular.user),
                        ),
                      ),
                      const SizedBox(height: AppSpace.s4),
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: "Email",
                          prefixIcon: Icon(PhosphorIconsRegular.envelope),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.s4),

                AppCard(
                  padding: const EdgeInsets.all(AppSpace.s6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Password", style: text.titleMedium),
                      const SizedBox(height: AppSpace.s1),
                      Text(
                        "Your current password is needed to change your email or password.",
                        style: text.bodySmall,
                      ),
                      const SizedBox(height: AppSpace.s4),
                      TextField(
                        controller: currentPassword,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: "Current password",
                          prefixIcon: Icon(PhosphorIconsRegular.lock),
                        ),
                      ),
                      const SizedBox(height: AppSpace.s4),
                      TextField(
                        controller: newPassword,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: "New password",
                          helperText: "Leave blank to keep your password",
                          prefixIcon: Icon(PhosphorIconsRegular.lockKey),
                        ),
                      ),
                    ],
                  ),
                ),

                if (error != null) ...[
                  const SizedBox(height: AppSpace.s4),
                  Row(
                    children: [
                      Icon(PhosphorIconsRegular.warning, color: c.danger, size: 20),
                      const SizedBox(width: AppSpace.s2),
                      Expanded(
                        child: Text(error!,
                            style: text.bodyMedium?.copyWith(color: c.danger)),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: AppSpace.s6),
                SizedBox(
                  width: double.infinity,
                  child: PressScale(
                    enabled: !isSaving,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : save,
                      child: Text(isSaving ? "Saving" : "Save changes"),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.s8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
