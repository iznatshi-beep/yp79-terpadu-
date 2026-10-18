import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import 'app.dart';
import 'core/config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Muat .env bila ada (pengembangan lokal). Di CI/produksi kredensial dikirim
  // lewat --dart-define. SEBELUMNYA dotenv.load() tidak pernah dipanggil
  // sehingga AppConfig.isConfigured selalu false walau .env tersedia.
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('.env dimuat.');
  } catch (_) {
    debugPrint('Tanpa file .env (normal pada build CI). '
        'Kredensial diambil dari --dart-define SUPABASE_URL/SUPABASE_ANON_KEY.');
  }

  // Inisialisasi Supabase hanya jika kredensial tersedia.
  // Jika anon key kosong, app tetap berjalan di mode "offline/no-backend"
  // untuk pengembangan frontend (halaman menampilkan status backend belum terhubung).
  if (AppConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
    } catch (e) {
      debugPrint('Gagal inisialisasi Supabase: $e');
    }
  } else {
    debugPrint(
        'Backend belum dikonfigurasi (SUPABASE_ANON_KEY kosong). Mode offline.');
  }

  runApp(const Yp79App());
}

/// Indikator global: apakah backend (Supabase) terinialisasi.
bool isBackendReady() => AppConfig.isConfigured;
