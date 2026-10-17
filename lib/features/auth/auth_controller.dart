import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/config.dart';
import '../../../core/models/session_profile.dart';
import '../../../core/theme.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/app_states.dart';
import '../beranda/beranda_page.dart';
import '../login/login_page.dart';

/// Gate utama: tampilkan login atau dashboard beranda sesuai status auth.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isConfigured) {
      return const _NoBackendGate();
    }
    return StreamBuilder<SessionProfile?>(
      stream: AuthService.sessionStream(),
      initialData: null,
      builder: (context, snap) {
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

/// Halaman bootstrap: baca session saat ini, tampilkan beranda atau login.
class AuthBootstrapPage extends StatefulWidget {
  const AuthBootstrapPage({super.key});

  @override
  State<AuthBootstrapPage> createState() => _AuthBootstrapPageState();
}

class _AuthBootstrapPageState extends State<AuthBootstrapPage> {
  SessionProfile? _profile;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (!AppConfig.isConfigured) {
      if (mounted) setState(() => _initialized = true);
      return;
    }
    final p = await AuthService.currentProfile();
    if (mounted) {
      setState(() {
        _profile = p;
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/logo.svg',
                width: 72,
                height: 72,
                placeholderBuilder: (_) => const CircularProgressIndicator(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Memuat...',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    if (_profile != null) {
      return BerandaPage(profile: _profile!);
    }
    return const LoginPage();
  }
}
