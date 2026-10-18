import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthResponse, OAuthProvider, Supabase;

import '../core/config.dart';

/// Masuk dengan Google (nyata, tanpa akun palsu).
///
/// Alur: Google Sign-In v7 mengambil ID token -> token itu ditukar menjadi sesi
/// Supabase lewat `signInWithIdToken`. Tidak ada jalur "selalu berhasil".
///
/// `serverClientId` WAJIB diisi dengan **Web client ID** (`client_type: 3`)
/// dari google-services.json, bukan client Android. Alasannya: Supabase
/// memeriksa klaim `aud` pada ID token, dan hanya Web client ID yang cocok
/// dengan konfigurasi provider Google di dashboard Supabase. Nilainya bukan
/// rahasia (memang ikut ter-commit di google-services.json) dan diisi lewat
/// `GOOGLE_WEB_CLIENT_ID` (.env lokal / --dart-define di CI).
class GoogleAuth {
  GoogleAuth._();

  static Future<void>? _inisialisasi;

  /// Apakah Google Sign-In siap dipakai di perangkat ini.
  static bool get tersedia {
    if (AppConfig.googleWebClientId.isEmpty) return false;
    try {
      return GoogleSignIn.instance.supportsAuthenticate();
    } catch (_) {
      return false;
    }
  }

  /// Inisialisasi sekali saja (kontrak google_sign_in 7.x).
  static Future<void> _siapkan() {
    return _inisialisasi ??= GoogleSignIn.instance.initialize(
      // clientId dibiarkan null: di Android diisi otomatis dari
      // google-services.json.
      serverClientId: AppConfig.googleWebClientId,
    );
  }

  /// Menampilkan pemilih akun Google lalu menukar ID token ke sesi Supabase.
  ///
  /// Melempar:
  ///  - [GoogleAuthDibatalkan] bila pengguna menutup pemilih akun (bukan error);
  ///  - [GoogleAuthGagal] untuk kegagalan lain, dengan pesan siap dibaca.
  static Future<AuthResponse> masuk() async {
    if (AppConfig.googleWebClientId.isEmpty) {
      throw const GoogleAuthGagal(
        'Masuk dengan Google belum dikonfigurasi (GOOGLE_WEB_CLIENT_ID kosong). '
        'Hubungi pengembang aplikasi.',
      );
    }

    try {
      await _siapkan();
    } catch (e) {
      throw GoogleAuthGagal('Google Sign-In gagal disiapkan: $e');
    }

    final GoogleSignInAccount akun;
    try {
      akun = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const GoogleAuthDibatalkan();
      }
      throw GoogleAuthGagal('Google menolak permintaan (${e.code.name}): '
          '${e.description ?? 'tanpa keterangan'}');
    }

    final idToken = akun.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const GoogleAuthGagal(
        'Google tidak mengirim ID token. Pastikan SHA-1 keystore aplikasi '
        'sudah didaftarkan di Firebase lalu unduh ulang google-services.json.',
      );
    }

    try {
      return await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
    } catch (e) {
      throw GoogleAuthGagal('Supabase menolak ID token Google: $e');
    }
  }

  /// Keluar dari akun Google (dipanggil bersama logout Supabase).
  static Future<void> keluar() async {
    try {
      if (AppConfig.googleWebClientId.isNotEmpty) {
        await _siapkan();
        await GoogleSignIn.instance.signOut();
      }
    } catch (e) {
      debugPrint('Keluar dari Google gagal (diabaikan): $e');
    }
  }
}

/// Pengguna menutup pemilih akun — bukan kesalahan yang perlu ditampilkan.
class GoogleAuthDibatalkan implements Exception {
  const GoogleAuthDibatalkan();
  @override
  String toString() => 'Dibatalkan.';
}

/// Kegagalan masuk dengan Google, pesannya sudah siap ditampilkan.
class GoogleAuthGagal implements Exception {
  const GoogleAuthGagal(this.pesan);
  final String pesan;
  @override
  String toString() => pesan;
}
