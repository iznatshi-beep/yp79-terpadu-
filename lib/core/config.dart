import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  /// Nama aplikasi (menampilkan nama sekolah terpadu).
  static const String appName = 'YP79 Terpadu';

  static const String _defaultUrl =
      String.fromEnvironment('SUPABASE_URL',
          defaultValue: 'https://yukqngrtgevveimhrwke.supabase.co');
  static const String _defaultAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  /// URL project Supabase produksi.
  static String get supabaseUrl {
    if (dotenv.isInitialized) {
      final v = dotenv.get('SUPABASE_URL');
      if (v != null && v.isNotEmpty) return v;
    }
    return _defaultUrl;
  }

  /// Anon key publik Supabase.
  static String get supabaseAnonKey {
    if (dotenv.isInitialized) {
      final v = dotenv.get('SUPABASE_ANON_KEY');
      if (v != null && v.isNotEmpty) return v;
    }
    return _defaultAnonKey;
  }

  /// Apakah kredensial backend sudah tersedia.
  static bool get isConfigured {
    return supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  }
}
