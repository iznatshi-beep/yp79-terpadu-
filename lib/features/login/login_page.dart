import 'package:flutter/material.dart';

import '../../../core/config.dart';
import '../../../core/theme.dart';
import '../../../services/api.dart';
import '../../../widgets/app_states.dart';

/// Layar login aplikasi YP79 Terpadu.
/// Autentikasi nyata: Supabase Auth email+password.
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
      _toast('Berhasil masuk. Menyiapkan dashboard...', durasi: 2);
    } on Exception catch (e) {
      _toast('Gagal masuk: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg, {int durasi = 4}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.danger,
        duration: Duration(seconds: durasi),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final backendReady = AppConfig.isConfigured;
    return Column(
      children: [
        if (!backendReady) const AppStatesBackendUnavailableBanner(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
                              ? () => _toast(
                                  'Fungsi pemulihan kata sandi membutuhkan '
                                      'konfigurasi server. Hubungi admin sekolah.',
                                )
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
                      const Divider(height: 1),
                      const SizedBox(height: 14),
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
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
