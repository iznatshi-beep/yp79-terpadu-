import 'package:flutter/material.dart';

import '../../../core/models/role.dart';
import '../../../core/models/session_profile.dart';
import '../../../core/theme.dart';

/// Layar pilih peran - tampil SETELAH login (email/Google) berhasil.
///
/// Alur client: pengguna masuk dulu, baru memilih peran sesi ini. HANYA dua
/// pilihan: Siswa atau Orang Tua. Guru, Guru Pembimbing, dan Admin dibuat
/// oleh admin sekolah lewat Manajemen Pengguna; akun staff TIDAK melewati
/// layar ini - mereka langsung masuk dashboard peran resminya.
///
/// Keamanan: pilihan hanya mengganti tampilan sesi ini. Peran resmi tetap di
/// database (profiles.role) dan seluruh data tetap dilindungi RLS server,
/// sehingga memilih peran yang bukan miliknya hanya menampilkan dashboard
/// kosong, bukan data orang lain.
class PilihPeranPage extends StatefulWidget {
  const PilihPeranPage({
    super.key,
    required this.profile,
    required this.onPilih,
  });

  final SessionProfile profile;

  /// Dipanggil saat pengguna menekan "Lanjutkan" dengan peran terpilih.
  final ValueChanged<Role> onPilih;

  @override
  State<PilihPeranPage> createState() => _PilihPeranPageState();
}

class _PilihPeranPageState extends State<PilihPeranPage> {
  Role? _pilih;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.school_rounded,
                      color: Colors.white, size: 32),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Masuk sebagai siapa?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink),
              ),
              const SizedBox(height: 6),
              Text(
                'Halo ${widget.profile.name ?? ''}. '
                'Pilih peran untuk sesi ini.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              _KartuPeran(
                role: Role.siswa,
                terpilih: _pilih == Role.siswa,
                onTap: () => setState(() => _pilih = Role.siswa),
              ),
              const SizedBox(height: 10),
              _KartuPeran(
                role: Role.orangTua,
                terpilih: _pilih == Role.orangTua,
                onTap: () => setState(() => _pilih = Role.orangTua),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed:
                    _pilih == null ? null : () => widget.onPilih(_pilih!),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
                child: const Text('Lanjutkan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KartuPeran extends StatelessWidget {
  const _KartuPeran({
    required this.role,
    required this.terpilih,
    required this.onTap,
  });

  final Role role;
  final bool terpilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (ikon, deskripsi) = switch (role) {
      Role.siswa => (
          Icons.school_outlined,
          'LMS, ujian CBT, jadwal, perpustakaan'
        ),
      Role.orangTua => (
          Icons.family_restroom_rounded,
          'Pantau presensi, nilai, & pembiayaan anak'
        ),
      _ => (Icons.help_outline, ''),
    };

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: terpilih ? AppColors.primaryBg : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: terpilih
              ? Border.all(color: AppColors.primary, width: 1.6)
              : null,
          boxShadow: terpilih ? null : appSoftShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: terpilih
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.tile),
              ),
              child: Icon(ikon,
                  size: 22,
                  color: terpilih ? Colors.white : AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(role.label,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(deskripsi,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(
              terpilih
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: terpilih ? AppColors.primary : AppColors.border,
            ),
          ],
        ),
      ),
    );
  }
}
