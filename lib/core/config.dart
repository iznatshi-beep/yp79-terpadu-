import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  /// Nama aplikasi (menampilkan nama sekolah terpadu).
  static const String appName = 'YP79 Terpadu';

  /// URL project Supabase produksi.
  ///
  /// SENGAJA tanpa nilai bawaan. Sebelumnya bawaan menunjuk project lama yang
  /// sudah mati (yukqngrtgevveimhrwke.supabase.co): build tanpa --dart-define
  /// jadi diam-diam menembak host mati dan aplikasi menggantung, bukan
  /// menampilkan pesan "backend belum terhubung" yang jujur.
  static const String _defaultUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String _defaultAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  /// Pesan kegagalan Supabase.initialize() saat aplikasi dibuka (diisi main).
  static String? lastInitError;

  /// URL project Supabase produksi.
  static String get supabaseUrl {
    if (dotenv.isInitialized) {
      // maybeGet: `.env` tanpa kunci ini tidak boleh melempar exception.
      final v = dotenv.maybeGet('SUPABASE_URL');
      if (v != null && v.isNotEmpty) return v;
    }
    return _defaultUrl;
  }

  /// Anon key publik Supabase.
  static String get supabaseAnonKey {
    if (dotenv.isInitialized) {
      final v = dotenv.maybeGet('SUPABASE_ANON_KEY');
      if (v != null && v.isNotEmpty) return v;
    }
    return _defaultAnonKey;
  }

  /// Apakah kredensial backend sudah tersedia.
  static bool get isConfigured {
    return supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  }
}
