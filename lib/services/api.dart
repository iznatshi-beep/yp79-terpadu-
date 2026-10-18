import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:supabase/supabase.dart' show SupabaseClient;

/// Klien terpusat untuk seluruh operasi database (Supabase).
class Api {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
  }
}
