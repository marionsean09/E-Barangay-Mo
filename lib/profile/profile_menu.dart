import 'package:flutter/material.dart';
import 'package:e_barangay_mo/theme/phosphor_icons.dart';

import 'package:e_barangay_mo/auth/auth_gate.dart';
import 'package:e_barangay_mo/profile/edit_profile_page.dart';
import 'package:e_barangay_mo/models/app_user.dart';
import 'package:e_barangay_mo/services/api_service.dart';
import 'package:e_barangay_mo/theme/app_colors.dart';
import 'package:e_barangay_mo/theme/app_tokens.dart';
import 'package:e_barangay_mo/utils/concern_format.dart';

class ProfileMenu extends StatelessWidget {
  const ProfileMenu({super.key, required this.user, this.onProfileChanged});

  final AppUser user;

  final ValueChanged<AppUser>? onProfileChanged;

  Future<void> _logOut(BuildContext context) async {
    // Revokes the refresh token on the server and clears the cookie.
    try {
      await ApiService.logout();
    } on Exception {
      // Signed out locally either way.
    }
    if (context.mounted) goToAuthGate(context);
  }

  Future<void> _editProfile(BuildContext context) async {
    final updated = await Navigator.push<AppUser>(
      context,
      MaterialPageRoute(builder: (_) => EditProfilePage(user: user)),
    );
    if (updated != null) onProfileChanged?.call(updated);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final name = user.name.isNotEmpty ? user.name : user.email;

    return Padding(
      padding: const EdgeInsets.only(right: AppSpace.s2),
      child: PopupMenuButton<String>(
        tooltip: "Profile",
        offset: const Offset(0, 48),
        onSelected: (value) => value == 'edit'
            ? _editProfile(context)
            : _logOut(context),
        itemBuilder: (_) => [
          PopupMenuItem(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: text.titleMedium),
                Text(user.email, style: text.bodySmall),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: Icon(PhosphorIconsRegular.userCircleGear),
              title: Text("Edit profile"),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuItem(
            value: 'logout',
            child: ListTile(
              leading: Icon(PhosphorIconsRegular.signOut),
              title: Text("Log out"),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.onHero,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: c.onHeroMuted, width: 2),
          ),
          child: Text(
            initials(name),
            style: text.labelMedium?.copyWith(color: c.primary, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
