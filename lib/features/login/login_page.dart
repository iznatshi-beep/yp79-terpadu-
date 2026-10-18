import 'package:flutter/material.dart';

import '../../../core/config.dart';
import '../../../core/theme.dart';
import '../../../services/api.dart';
import '../../../services/google_auth.dart';
import '../../../widgets/app_states.dart';

/// Layar login aplikasi YP79 Terpadu.
///
/// Autentikasi nyata: Supabase Auth (email + kata sandi) dan Google Sign-In.
///
/// PENTING: halaman ini mengembalikan [Scaffold] sendiri. Sebelumnya ia hanya
/// mengembalikan `Column` dan bergantung pada pembungkus di luar; begitu jalur
/// auth memanggilnya langsung, layar menjadi HITAM dengan garis kuning di bawah
/// teks (tanda widget tidak punya leluhur Material/Scaffold).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await Api.client.auth
          .signInWithPassword(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
          );
      // Navigasi tidak dilakukan di sini: AuthGate mendengarkan
      // onAuthStateChange sehingga layar berpindah otomatis setelah sesi dibuat.
      _toast('Berhasil masuk. Menyiapkan dashboard...',
          durasi: 2, sukses: true);
    } on Exception catch (e) {
      _toast('Gagal masuk: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Masuk dengan Google: ID token dari Google ditukar menjadi sesi Supabase.
  /// Tidak ada jalur yang selalu berhasil — kegagalan ditampilkan apa adanya.
  Future<void> _google() async {
    setState(() => _loading = true);
    try {
      await GoogleAuth.masuk();
      _toast('Berhasil masuk dengan Google.', durasi: 2, sukses: true);
    } on GoogleAuthDibatalkan {
      // Pengguna menutup pemilih akun: bukan kesalahan.
    } on GoogleAuthGagal catch (e) {
      _toast(e.pesan, durasi: 8);
    } catch (e) {
      _toast('Gagal masuk dengan Google: $e', durasi: 8);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Kirim tautan reset kata sandi ke email terdaftar — fungsi nyata
  /// Supabase Auth, menggantikan tombol dekoratif sebelumnya.
  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _toast('Isi kolom email dulu, lalu tekan "Lupa kata sandi?".');
      return;
    }
    setState(() => _loading = true);
    try {
      await Api.client.auth.resetPasswordForEmail(email);
      _toast('Tautan reset kata sandi dikirim ke $email. Periksa kotak masuk.',
          durasi: 6, sukses: true);
    } on Exception catch (e) {
      _toast('Gagal mengirim tautan reset: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg, {int durasi = 4, bool sukses = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: sukses ? AppColors.success : AppColors.danger,
        duration: Duration(seconds: durasi),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final backendReady = AppConfig.isConfigured;
    final googleSiap = backendReady && GoogleAuth.tersedia;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
      children: [
        if (!backendReady) const AppStatesBackendUnavailableBanner(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: const Text(
                    AppConfig.appName,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: const Text(
                    'Portal Sekolah Terpadu',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        enabled: backendReady && !_loading,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.alternate_email_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email wajib diisi.';
                          }
                          if (!v.contains('@')) {
                            return 'Format email tidak valid.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        enabled: backendReady && !_loading,
                        decoration: InputDecoration(
                          labelText: 'Kata Sandi',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Minimal 6 karakter.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: backendReady && !_loading
                              ? _resetPassword
                              : null,
                          child: const Text(
                            'Lupa kata sandi?',
                            style: TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FilledButton(
                        onPressed: backendReady && !_loading ? _submit : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Masuk',
                                style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700),
                              ),
                      ),
                      const SizedBox(height: 18),
                      // Pembatas "atau" + tombol Google, seperti showcase.
                      const Row(
                        children: [
                          Expanded(child: Divider(height: 1)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'atau',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(height: 1)),
                        ],
                      ),

                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        // Nonaktif (dengan alasan tertulis) bila backend belum
                        // siap atau GOOGLE_WEB_CLIENT_ID belum diisi — bukan
                        // tombol dekoratif yang diam-diam tidak bekerja.
                        onPressed: googleSiap && !_loading ? _google : null,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          side: const BorderSide(color: AppColors.line),
                          foregroundColor: AppColors.ink,
                        ),
                        icon: const _LambangGoogle(),
                        label: const Text(
                          'Masuk dengan Google',
                          style: TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (backendReady && !googleSiap) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Masuk dengan Google belum aktif di build ini '
                          '(GOOGLE_WEB_CLIENT_ID belum diisi).',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11.5, color: AppColors.textSecondary),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Text(
                        backendReady
                            ? 'Akun baru dibuat oleh pihak sekolah. '
                                'Hubungi admin untuk aktivasi.'
                            : 'Masih dalam tahap pengembangan.',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
        ),
      ),
    );
  }
}

/// Lambang "G" Google empat warna, digambar manual supaya tidak menambah
/// paket aset hanya untuk satu ikon.
class _LambangGoogle extends StatelessWidget {
  const _LambangGoogle();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _PainterGoogleG()),
    );
  }
}

class _PainterGoogleG extends CustomPainter {
  const _PainterGoogleG();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    final rect = Rect.fromCircle(center: c, radius: r * 0.82);
    final stroke = r * 0.46;

    void busur(double mulai, double sapuan, Color warna) {
      canvas.drawArc(
        rect,
        mulai,
        sapuan,
        false,
        Paint()
          ..color = warna
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt,
      );
    }

    // Sudut dalam radian; -pi/2 adalah arah jam 12.
    busur(-1.05, 2.10, const Color(0xFF4285F4)); // biru (kanan)
    busur(1.05, 1.57, const Color(0xFF34A853)); // hijau (kiri bawah)
    busur(2.62, 1.10, const Color(0xFFFBBC05)); // kuning (bawah)
    busur(-2.60, 1.55, const Color(0xFFEA4335)); // merah (atas)
    // Batang horizontal huruf G.
    canvas.drawRect(
      Rect.fromLTWH(r * 0.98, r * 0.42, r * 0.92, r * 0.30),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
