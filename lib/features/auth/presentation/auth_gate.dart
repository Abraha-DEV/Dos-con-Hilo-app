import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isConfigured) {
      return child;
    }
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            Supabase.instance.client.auth.currentSession == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (Supabase.instance.client.auth.currentSession == null) {
          return const LoginPage();
        }
        return child;
      },
    );
  }
}
