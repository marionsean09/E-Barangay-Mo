import 'package:flutter/material.dart';
import 'package:e_barangay_mo/models/app_user.dart';
import 'package:e_barangay_mo/services/api_service.dart';
import 'package:e_barangay_mo/auth/login_page.dart';
import 'package:e_barangay_mo/resident/resident_dashboard.dart';
import 'package:e_barangay_mo/admin/admin_dashboard.dart';

void goToAuthGate(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const AuthGate()),
    (route) => false,
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Uses the httpOnly refresh cookie to get a fresh access token.
  late final Future<AppUser?> _userFuture = ApiService.restoreSession();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUser?>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginPage();
        }

        // UI routing only; admin endpoints are protected on the server.
        if (user.isAdmin) {
          return AdminDashboard(user: user);
        }
        return ResidentDashboard(user: user);
      },
    );
  }
}
