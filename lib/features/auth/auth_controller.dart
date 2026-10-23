import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth_bus.dart';
import '../../../core/config.dart';
import '../../../core/models/role.dart';
import '../../../core/models/session_profile.dart';
import '../../../core/theme.dart';
import '../../../services/auth_service.dart';
import '../beranda/beranda_page.dart';
import '../login/login_page.dart';
import 'pilih_peran_page.dart';

/// Gate utama: tampilkan login atau dashboard beranda sesuai status auth.
///
/// Kenapa tidak hanya bergantung pada `onAuthStateChange`: di sebagian
/// perangkat event pertama stream itu tidak pernah datang (pemulihan sesi di
/// dalam `Supabase.initialize()` gagal / tidak selesai). Akibatnya stream bisu
/// — tidak ada data, tidak ada error — dan layar "Memuat data sesi..." berputar
/// tanpa akhir. Karena itu gerbang memakai tiga lapis: sinyal dari main()
/// (`authChanged`), pembacaan sesi langsung, dan pemeriksaan berkala. Semua
/// jalur membaca sesi dari penyimpanan lokal, bukan jaringan.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  SessionProfile? _profil;
  String? _error;
  bool _siap = false;
  bool _sedangMemuat = false;
  Timer? _pemantau;

  @override
  void initState() {
    super.initState();
    if (!AppConfig.isConfigured) return;

    // Jalur 1: sinyal dari main() (login, logout, refresh token).
    authChanged.addListener(_muat);
    _muat();

    // Jalur 2: pemeriksaan berkala. Di sebagian perangkat tidak ada sinyal
    // autentikasi sama sekali; tanpa ini layar "Memuat data sesi..." bisa
    // berputar tanpa akhir. Hanya membaca sesi lokal, jadi ringan.
    _pemantau = Timer.periodic(const Duration(seconds: 4), (_) => _muat());
  }

  @override
  void dispose() {
    _pemantau?.cancel();
    authChanged.removeListener(_muat);
    super.dispose();
  }

  /// Baca sesi dari penyimpanan lokal (tanpa jaringan).
  Future<void> _muat() async {
    if (_sedangMemuat) return;
    _sedangMemuat = true;
    try {
      final profil =
          await AuthService.currentProfile().timeout(const Duration(seconds: 10));
      if (!mounted) return;
      // Hanya bangun ulang bila benar-benar berubah, supaya pemeriksaan
      // berkala tidak membuat layar berkedip tiap 4 detik.
      final berubah = _profil?.sub != profil?.sub || _profil?.role != profil?.role;
      if (!_siap || berubah || _error != null) {
        setState(() {
          _profil = profil;
          _siap = true;
          _error = null;
        });
      } else {
        _profil = profil;
      }
    } on TimeoutException {
      if (mounted && !_siap) {
        setState(() => _error = 'Server tidak merespons dalam 10 detik. '
            'Periksa koneksi internet lalu tekan Coba lagi.');
      }
    } catch (e) {
      // Tampilkan kegagalan hanya bila belum pernah berhasil membaca sesi;
      // gangguan sesaat pada pemeriksaan berkala tidak boleh menendang
      // pengguna keluar dari dashboard yang sudah terbuka.
      if (mounted && !_siap) setState(() => _error = _pesan(e));
    } finally {
      _sedangMemuat = false;
    }
  }

  /// Sertakan sebab kegagalan startup kalau ada, supaya pesannya bisa
  /// ditindaklanjuti (bukan cuma "terjadi kesalahan").
  String _pesan(Object e) {
    final awal = AppConfig.lastInitError;
    return awal == null ? '$e' : 'Supabase gagal disiapkan: $awal';
  }

  /// Peran yang dipilih pengguna untuk sesi SISWA/ORTU. Tersimpan permanen di
  /// perangkat (shared_preferences) terikat user id, sehingga tidak ditanyakan
  /// ulang setiap aplikasi dibuka ulang. Pilihan hanya mengganti tampilan;
  /// data tetap dilindungi RLS server.
  Role? _peranSesi;
  String? _peranSesiUser;

  /// Peran sesi yang dipilih pengguna, dikunci permanen per user id di
  /// perangkat (shared_preferences). Diisi ASYNCHRONOUS saat build pertama
  /// kali profil diketahui; sebelum itu, layarnya adalah SplashScreen
  /// (jangan tampilkan layar pilih peran / dashboard) agar tidak berkedip.
  Future<void> _simpanPeran(String userId, Role r) async {
    // Tandai pengguna secara lokal. Ini TIDAK mengubah peran di database
    // (peran resmi tetap profiles.role + RLS server); hanya mengunci
    // tampilan sesi perangkat ini.
    _peranSesi = r;
    _peranSesiUser = userId;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('peran_sesi_$userId', r.name);
    } catch (_) {
      // Gagal menyimpan: pilihan tetap berlaku untuk sesi ini saja.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isConfigured) {
      return const _NoBackendGate();
    }
    if (_error != null) {
      return _AuthErrorScreen(message: _error!, onRetry: _muat);
    }
    if (!_siap) {
      return const _SplashScreen();
    }
    final profil = _profil;
    if (profil == null) {
      return const LoginPage();
    }
    // Muat pilihan peran tersimpan.
    //
    // ATURAN PERAN (sesuai spesifikasi client):
    // - Siswa / Orang Tua: hanya dua pilihan tampilan (Siswa, Orang Tua),
    //   dipilih sekali lalu DIKUNCI di perangkat (shared_preferences).
    //   Selama penyimpanan tersisa, pengguna TIDAK akan melihat lagi
    //   layar pilih peran — termasuk setelah aplikasi ditutup lama.
    //   Peran resmi di database tidak berubah; seluruh data tetap
    //   dilindungi RLS server (memilih tampilan bukan hak akses).
    // - Guru / Guru Pembimbing / Admin: tidak ada layar pilih peran;
    //   langsung masuk dashboard peran resminya dari database.
    if (profil.role.isStaff) {
      _peranSesi = null;
      return BerandaPage(profile: _profilDenganPeran(profil, profil.role));
    }
    if (_peranSesiUser != profil.sub) {
      // User berganti / belum dimuat: baca pilihan tersimpan dulu.
      // Tampilkan SplashScreen sampai selesai (tidak berkedip).
      _peranSesiUser = profil.sub;
      _peranSesi = null;
      // Baca async; build berikutnya memakai hasil.
      SharedPreferences.getInstance().then((sp) {
        return sp.getString('peran_sesi_${profil.sub}');
      }).then((tersimpan) {
        if (!mounted) return;
        if (tersimpan == Role.siswa.name || tersimpan == Role.orangTua.name) {
          _peranSesi = Role.fromString(tersimpan);
          setState(() {});
        }
      });
      return const _SplashScreen();
    }
    if (_peranSesi == null) {
      // Pilihan pertama kali untuk pengguna ini: tampilkan layar pilih peran.
      return PilihPeranPage(
        profile: profil,
        onPilih: (r) {
          final uid = profil.sub;
          if (uid == null) return;
          _simpanPeran(uid, r);
        },
      );
    }
    return BerandaPage(profile: _profilDenganPeran(profil, _peranSesi ?? profil.role));
  }

  /// Salin profil dengan peran sesi (tanpa mengubah data login asli).
  SessionProfile _profilDenganPeran(SessionProfile p, Role r) => SessionProfile(
        role: r,
        name: p.name,
        sub: p.sub,
        email: p.email,
        studentId: r == Role.siswa ? p.studentId : p.studentId,
        parentStudentIds: p.parentStudentIds,
      );
}

/// Gate saat backend tidak dikonfigurasi: menampilkan login + banner.
class _NoBackendGate extends StatelessWidget {
  const _NoBackendGate();

  @override
  Widget build(BuildContext context) => const LoginPage();
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
