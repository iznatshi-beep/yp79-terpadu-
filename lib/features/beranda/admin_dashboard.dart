import 'package:flutter/material.dart';

import '../../../core/models/session_profile.dart';
import '../../../core/theme.dart';
import '../../../services/repositories.dart';
import '../../../widgets/app_states.dart';
import '../../../widgets/dashboard_widgets.dart';
import '../../../widgets/quick_actions.dart';
import '../akademik/nilai_input_page.dart';
import '../akademik/presensi_input_page.dart';
import '../akademik/rekap_presensi_page.dart';
import '../admin/broadcast_page.dart';
import '../admin/manajemen_pengguna_page.dart';
import '../admin/gps_bus_page.dart';
import '../admin/mode_sopir_page.dart';
import '../akademik/leger_nilai_page.dart';
import '../akademik/verifikasi_staf_page.dart';
import '../cbt/kelola_exam_page.dart';
import '../admin/master_data_page.dart';
import '../admin/master_siswa_page.dart';
import '../ppdb/ppdb_page.dart';
import '../izin/izin_page.dart';

/// Dashboard Administrator: statistik nyata dari DB + akses modul.
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key, required this.profile});

  final SessionProfile profile;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        FutureBuilder<List<({String label, String value, String subtitle, IconData icon, Color color})>>(
          future: _stats(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: SkeletonRow(),
              );
            }
            final stats = snap.data ?? const [];
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HeroSummaryCard(
                    greeting: 'Assalamualaikum, ${profile.name ?? 'Admin'} 👋',
                    title: 'Ringkasan operasional hari ini',
                    value: stats.isEmpty ? '0' : stats.first.value,
                    subtitle: stats.length > 1
                        ? '${stats[1].label}: ${stats[1].value} · ${stats[0].subtitle}'
                        : 'Belum ada data presensi hari ini',
                    icon: Icons.school_rounded,
                  ),
                  const SizedBox(height: 18),
                  const SectionHeader(title: 'Aksi Cepat'),
                  const SizedBox(height: 6),
                  ModulAksiGrid(
                    items: [
                      ModulAksi(
                        label: 'Kelola Akun',
                        icon: Icons.manage_accounts_outlined,
                        builder: (_) => const ManajemenPenggunaPage(),
                      ),
                      ModulAksi(
                        label: 'PPDB',
                        icon: Icons.how_to_reg_outlined,
                        builder: (_) => const PpdbPage(),
                      ),
                      ModulAksi(
                        label: 'Broadcast',
                        icon: Icons.campaign_outlined,
                        builder: (_) => const BroadcastPengumumanPage(),
                      ),
                      ModulAksi(
                        label: 'Kelola Ujian',
                        icon: Icons.edit_note_rounded,
                        builder: (_) => const KelolaExamPage(),
                      ),
                      ModulAksi(
                        label: 'Verifikasi',
                        icon: Icons.fact_check_rounded,
                        builder: (_) => const VerifikasiStafPage(),
                      ),
                      ModulAksi(
                        label: 'Leger Nilai',
                        icon: Icons.table_chart_rounded,
                        builder: (_) => const LegerNilaiPage(),
                      ),
                      ModulAksi(
                        label: 'Bus & GPS',
                        icon: Icons.directions_bus_outlined,
                        builder: (_) => const GpsBusPage(),
                      ),
                      ModulAksi(
                        label: 'Mode Sopir',
                        icon: Icons.navigation_rounded,
                        builder: (_) => const ModeSopirPage(),
                      ),
                      ModulAksi(
                        label: 'Input Presensi',
                        icon: Icons.fact_check_outlined,
                        builder: (_) => PresensiInputPage(profile: profile),
                      ),
                      ModulAksi(
                        label: 'Input Nilai',
                        icon: Icons.grade_outlined,
                        builder: (_) => NilaiInputPage(profile: profile),
                      ),
                      ModulAksi(
                        label: 'Pengajuan Izin',
                        icon: Icons.event_busy_outlined,
                        builder: (_) => IzinPage(profile: profile),
                      ),
                      ModulAksi(
                        label: 'Data Master',
                        icon: Icons.domain_outlined,
                        builder: (_) => const MasterDataPage(),
                      ),
                      ModulAksi(
                        label: 'Data Siswa',
                        icon: Icons.groups_2_rounded,
                        builder: (_) => const MasterSiswaPage(),
                      ),
                      ModulAksi(
                        label: 'Rekap Presensi',
                        icon: Icons.summarize_outlined,
                        builder: (_) => RekapPresensiPage(profile: profile),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const SectionHeader(title: 'Ringkasan Hari Ini'),
                  const SizedBox(height: 4),
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.6,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (final s in stats)
                        DashboardStatCard(
                          label: s.label,
                          value: s.value,
                          subtitle: s.subtitle,
                          icon: s.icon,
                          color: s.color,
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        FutureBuilder<QueryResult<RowData>>(
          future: Repos.announcements(limit: 3),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(height: 10);
            }
            final ann = snap.data?.data ?? const [];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Pengumuman Terbaru'),
                  if (ann.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: EmptyState(
                        title: 'Belum ada pengumuman',
                        message: 'Pengumuman sekolah akan tampil di sini.',
                        icon: Icons.campaign_outlined,
                      ),
                    )
                  else
                    for (final a in ann)
                      _AnnouncementTile(
                        judul: a['judul'] as String? ?? '',
                        isi: a['isi'] as String?,
                        prioritas: a['prioritas'] as String? ?? 'biasa',
                        waktu: a['dipublikasikan_pada'] as String?,
                      ),
                ],
              ),
            );
          },
        ),
        FutureBuilder<QueryResult<RowData>>(
          future: Repos.notifications(limit: 5),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(height: 10);
            }
            final notifs = snap.data?.data ?? const [];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Notifikasi Terbaru'),
                  if (notifs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: EmptyState(
                        title: 'Tidak ada notifikasi',
                        message: 'Notifikasi masuk akan tampil di sini.',
                        icon: Icons.notifications_none,
                      ),
                    )
                  else
                    for (final n in notifs)
                      _NotificationTile(
                        judul: n['judul'] as String? ?? '',
                        pesan: n['pesan'] as String?,
                        waktu: n['created_at'] as String?,
                        sudahDibaca: n['dibaca_pada'] != null,
                        onDibaca: () =>
                            Repos.markNotificationRead(n['id'] as String? ?? ''),
                      ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<List<({String label, String value, String subtitle, IconData icon, Color color})>> _stats() async {
    final now = DateTime.now();
    final today = now.toIso8601String().substring(0, 10);
    final results = await Future.wait([
      Repos.attendanceToday(),
      Repos.leaves(status: 'diajukan'),
    ]);
    final presensiHariIni = results[0].data.length;
    final izinMenunggu = results[1].data.length;
    return [
      (
        label: 'Presensi Hari Ini',
        value: '$presensiHariIni',
        subtitle: 'tercatat sampai $today',
        icon: Icons.fact_check_outlined,
        color: AppColors.primary,
      ),
      (
        label: 'Izin Menunggu',
        value: '$izinMenunggu',
        subtitle: 'perlu keputusan',
        icon: Icons.hourglass_empty_rounded,
        color: AppColors.warning,
      ),
    ];
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({
    required this.judul,
    this.isi,
    required this.prioritas,
    this.waktu,
  });

  final String judul;
  final String? isi;
  final String prioritas;
  final String? waktu;

  @override
  Widget build(BuildContext context) {
    final isDarurat = prioritas == 'darurat';
    final isPenting = prioritas == 'penting';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: appSoftShadow,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(
                label: prioritas.toUpperCase(),
                state: isDarurat
                    ? BadgeState.danger
                    : (isPenting ? BadgeState.warning : BadgeState.info),
              ),
              const Spacer(),
              if (waktu != null)
                Text(
                  waktu!.split('T')[0],
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            judul,
            style: const TextStyle(
                fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (isi != null && isi!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              isi!,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.judul,
    this.pesan,
    this.waktu,
    required this.sudahDibaca,
    required this.onDibaca,
  });

  final String judul;
  final String? pesan;
  final String? waktu;
  final bool sudahDibaca;
  final VoidCallback onDibaca;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onDibaca,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: appSoftShadow,
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              sudahDibaca
                  ? Icons.notifications_none_outlined
                  : Icons.notifications_active_outlined,
              size: 18,
              color: sudahDibaca ? AppColors.textSecondary : AppColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    judul,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: sudahDibaca ? FontWeight.w600 : FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (pesan != null && pesan!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      pesan!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (waktu != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  waktu!.split('T')[0],
                  style: const TextStyle(
                      fontSize: 10.5, color: AppColors.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
