import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import 'app.dart';
import 'core/config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

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

  // Firebase (Crashlytics + Analytics) sebelum Supabase: kalau gagal,
  // app tetap lanjut (hanya fitur laporan crash yang nonaktif).
  await initFirebase();

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

/// Firebase Analytics — null bila Firebase gagal/tidak dikonfigurasi.
/// Dipakai fitur lain untuk mencatat peristiwa (mis. `firebaseAnalytics
/// ?.logEvent(name: 'buka_rapor'))`.
FirebaseAnalytics? firebaseAnalytics;

/// Inisialisasi Firebase + pemasangan pelapor crash.
///
/// Dibungkus try/catch dengan sengaja: kalau `google-services.json` tidak
/// tersedia atau perangkat tanpa Google Play Services, aplikasi sekolah tetap
/// harus bisa dibuka. Kegagalan di sini hanya mematikan telemetri.
Future<void> initFirebase() async {
  try {
    await Firebase.initializeApp();
    firebaseAnalytics = FirebaseAnalytics.instance;

    final crashlytics = FirebaseCrashlytics.instance;
    // Debug diofkan supaya error saat ngoding tidak masuk laporan produksi.
    await crashlytics.setCrashlyticsCollectionEnabled(kReleaseMode);

    // Error Flutter (build/layout/gesture) -> fatal.
    final sebelumnya = FlutterError.onError;
    FlutterError.onError = (details) {
      crashlytics.recordError(details.exception, details.stack, fatal: true);
      if (sebelumnya != null) {
        sebelumnya(details);
      } else {
        FlutterError.presentError(details);
      }
    };

    // Error Dart di luar frame Flutter, mis. di isolate utama.
    WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };

    debugPrint('Firebase siap. Crashlytics: '
        '${kReleaseMode ? "aktif" : "nonaktif (mode debug)"}.');
  } catch (e) {
    debugPrint('Firebase tidak aktif: $e');
  }
}
