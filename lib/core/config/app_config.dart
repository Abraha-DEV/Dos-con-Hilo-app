import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class AppConfig {
  static const _url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pqxbhgjhlelajzqfefsf.supabase.co',
  );
  static const _publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const _legacyAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static String get _clientKey =>
      _publishableKey.isNotEmpty
          ? _publishableKey
          : _legacyAnonKey.isNotEmpty
              ? _legacyAnonKey
              : 'sb_publishable_ICm5J7EIeYYDoyvc3TtGjA_MlrFOxv6';

  static bool get isConfigured => _url.isNotEmpty && _clientKey.isNotEmpty;

  static Future<void> initialize() async {
    if (!isConfigured) return;
    await Supabase.initialize(url: _url, publishableKey: _clientKey);
  }
}
