import 'package:flutter/material.dart';

import '../../../core/config.dart';
import '../../../core/models/session_profile.dart';
import '../../../core/theme.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/app_states.dart';
import '../beranda/beranda_page.dart';
import '../login/login_page.dart';

/// Gate utama: tampilkan login atau dashboard beranda sesuai status auth.
///
/// Stream dibuat SEKALI di initState, bukan di dalam build(). Sebelumnya root
/// app memakai `AuthBootstrapPage` yang hanya membaca session satu kali,
/// sehingga login berhasil tetapi layar tidak pernah berpindah ke dashboard.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Stream<SessionProfile?>? _stream;

  @override
  void initState() {
    super.initState();
    if (AppConfig.isConfigured) {
      _stream = AuthService.sessionStream();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isConfigured) {
      return const _NoBackendGate();
    }
    return StreamBuilder<SessionProfile?>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return _AuthErrorScreen(message: '${snap.error}');
        }
        if (!snap.hasData) {
          return const _SplashScreen();
        }
        final profile = snap.data;
        if (profile == null) {
          return const LoginPage();
        }
        return BerandaPage(profile: profile);
      },
    );
  }
}

/// Gate saat backend tidak dikonfigurasi: menampilkan login + banner.
class _NoBackendGate extends StatelessWidget {
  const _NoBackendGate();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const AppStatesBackendUnavailableBanner(),
          Expanded(
            child: LoginPage(),
          ),
        ],
      ),
    );
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
  const _AuthErrorScreen({required this.message});
  final String message;

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
            ],
          ),
        ),
      ),
    );
  }
}
