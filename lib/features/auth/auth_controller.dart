import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config.dart';
import '../../../core/models/session_profile.dart';
import '../../../core/theme.dart';
import '../../../services/auth_service.dart';
import '../beranda/beranda_page.dart';
import '../login/login_page.dart';

/// Gate utama: tampilkan login atau dashboard beranda sesuai status auth.
///
/// Kenapa tidak hanya bergantung pada `onAuthStateChange`: event pertama
/// (`initialSession`) baru dipancarkan SETELAH pemulihan sesi di dalam
/// `Supabase.initialize()` selesai. Kalau pemulihan itu gagal (mis. perangkat
/// gagal membaca sesi tersimpan), stream tidak pernah memancarkan apa pun —
/// tidak ada data dan tidak ada error — sehingga layar "Memuat data sesi..."
/// berputar tanpa akhir. Sekarang gerbang memakai DUA jalur: dengarkan
/// perubahan sesi (untuk login/logout) DAN baca sesi sekali langsung dengan
/// batas waktu.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<SessionProfile?>? _langganan;
  SessionProfile? _profil;
  String? _error;
  bool _siap = false;

  @override
  void initState() {
    super.initState();
    if (AppConfig.isConfigured) _mulai();
  }

  @override
  void dispose() {
    _langganan?.cancel();
    super.dispose();
  }

  Future<void> _mulai() async {
    if (mounted) {
      setState(() {
        _siap = false;
        _error = null;
      });
    }

    // Jalur 1: perubahan sesi (login, logout, refresh token).
    try {
      await _langganan?.cancel();
      _langganan = AuthService.sessionStream().listen(
        (profil) {
          if (!mounted) return;
          setState(() {
            _profil = profil;
            _siap = true;
            _error = null;
          });
        },
        onError: (Object e) {
          if (!mounted) return;
          setState(() => _error = _pesan(e));
        },
      );
    } catch (e) {
      if (mounted) setState(() => _error = _pesan(e));
    }

    // Jalur 2: pembacaan langsung. Inilah yang menjamin layar tidak pernah
    // berputar selamanya walau jalur 1 bisu.
    try {
      final profil = await AuthService.currentProfile()
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _profil = profil;
        _siap = true;
        _error = null;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _error = 'Server tidak merespons dalam 12 detik. '
          'Periksa koneksi internet lalu tekan Coba lagi.');
    } catch (e) {
      if (mounted) setState(() => _error = _pesan(e));
    }
  }

  /// Sertakan sebab kegagalan startup kalau ada, supaya pesannya bisa
  /// ditindaklanjuti (bukan cuma "terjadi kesalahan").
  String _pesan(Object e) {
    final awal = AppConfig.lastInitError;
    return awal == null ? '$e' : 'Supabase gagal disiapkan: $awal';
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isConfigured) {
      return const _NoBackendGate();
    }
    if (_error != null) {
      return _AuthErrorScreen(message: _error!, onRetry: _mulai);
    }
    if (!_siap) {
      return const _SplashScreen();
    }
    final profil = _profil;
    if (profil == null) {
      return const LoginPage();
    }
    return BerandaPage(profile: profil);
  }
}

/// Gate saat backend tidak dikonfigurasi: menampilkan login + banner.
class _NoBackendGate extends StatelessWidget {
  const _NoBackendGate();

  @override
  Widget build(BuildContext context) {
    // LoginPage sudah menampilkan banner "Backend belum terhubung" ketika
    // kredensial belum ada. Sebelumnya banner dirender DUA KALI (di sini dan
    // di dalam LoginPage) sehingga tampil bertumpuk di layar.
    return const Scaffold(body: LoginPage());
  }
}

/// Titik masuk root app (dipakai `lib/app.dart`).
class AuthBootstrapPage extends StatelessWidget {
  const AuthBootstrapPage({super.key});

  @override
  Widget build(BuildContext context) => const AuthGate();
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: const Icon(Icons.school_rounded,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 18),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(height: 14),
            const Text(
              'Memuat data sesi...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthErrorScreen extends StatelessWidget {
  const _AuthErrorScreen({required this.message, this.onRetry});
  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 44, color: AppColors.danger),
              const SizedBox(height: 12),
              const Text(
                'Gagal membaca sesi',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textSecondary),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => onRetry!(),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Coba lagi'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
