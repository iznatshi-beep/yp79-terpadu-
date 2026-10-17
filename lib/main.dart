import 'package:flutter/material.dart';
import 'package:supabase/supabase.dart';
import 'package:supabase_flutter/supabase.dart' show Supabase;

import 'app.dart';
import 'core/config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
