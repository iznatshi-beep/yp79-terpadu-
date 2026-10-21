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
import '../akademik/leger_nilai_page.dart';
import '../akademik/verifikasi_staf_page.dart';
import '../cbt/kelola_exam_page.dart';
import '../izin/izin_page.dart';
import '../lms/materi_page.dart';

/// Dashboard Guru: kelas yang diampu + presensi + materi + tugas.
class GuruDashboard extends StatelessWidget {
  const GuruDashboard({super.key, required this.profile});

  final SessionProfile profile;

  @override
  Widget build(BuildContext context) {
    final uid = Repos.uid;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        FutureBuilder<QueryResult<RowData>>(
          future: Repos.teacherAssignments(teacherId: uid),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: SkeletonRow(),
              );
            }
            final assignments = snap.data?.data ?? const [];
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HeroSummaryCard(
                    greeting: 'Assalamualaikum, ${profile.name ?? 'Guru'} 👋',
                    title: 'Kelas yang Anda ampu',
                    value: '${assignments.length}',
                    subtitle: assignments.isEmpty
                        ? 'Belum ada penugasan mengajar dari admin'
                        : 'Penugasan aktif tahun ajaran ini',
                    icon: Icons.menu_book_rounded,
                  ),
                  const SizedBox(height: 18),
                  const SectionHeader(title: 'Aksi Cepat'),
                  const SizedBox(height: 6),
                  ModulAksiGrid(
                    items: [
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
                        label: 'Rekap Absen',
                        icon: Icons.summarize_outlined,
                        builder: (_) => RekapPresensiPage(profile: profile),
                      ),
                      ModulAksi(
                        label: 'Terbitkan Materi',
                        icon: Icons.cloud_upload_outlined,
                        builder: (_) => const MateriPage(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const SectionHeader(
                      title: 'Kelas & Mata Pelajaran Diampu'),
                  if (assignments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: EmptyState(
                        title: 'Belum ada penugasan',
                        message: 'Admin belum menetapkan kelas/mata pelajaran untuk Anda.',
                        icon: Icons.school_outlined,
                      ),
                    )
                  else
                    for (final a in assignments)
                      _AssignmentTile(
                        kelas: (a['classes'] as Map?)?['nama'] as String? ?? '',
                        mapel:
                            '${(a['subjects'] as Map?)?['kode'] as String? ?? ''}'
                            ' — '
                            '${(a['subjects'] as Map?)?['nama'] as String? ?? ''}',
                        peran: a['peran'] as String? ?? 'pengampu',
                        tahunAjaran: a['tahun_ajaran'] as String? ?? '',
                      ),
                ],
              ),
            );
          },
        ),
        FutureBuilder<QueryResult<Map<String, dynamic>>>(
          future: Repos.materials(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(height: 10);
            }
            final mats = snap.data?.data ?? const [];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Materi Pembelajaran'),
                  if (mats.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: EmptyState(
                        title: 'Belum ada materi',
                        message: 'Materi LMS yang Anda buat akan tampil di sini.',
                        icon: Icons.menu_book_outlined,
                      ),
                    )
                  else
                    for (final m in mats)
                      _MaterialRow(
                        judul: m['judul'] as String? ?? '',
                        namaKelas: (m['classes'] as Map?)?['nama'] as String?,
                        namaMapel: (m['subjects'] as Map?)?['nama'] as String?,
                        dipublikasikan: m['dipublikasikan'] as bool? ?? false,
                      ),
                ],
              ),
            );
          },
        ),
        FutureBuilder<QueryResult<Map<String, dynamic>>>(
          future: Repos.assignments(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(height: 10);
            }
            final asgs = snap.data?.data ?? const [];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Tugas Diberikan'),
                  if (asgs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: EmptyState(
                        title: 'Belum ada tugas',
                        message: 'Tugas yang Anda buat akan tampil di sini.',
                        icon: Icons.assignment_outlined,
                      ),
                    )
                  else
                    for (final a in asgs)
                      _AssignmentRow(
                        judul: a['judul'] as String? ?? '',
                        status: a['status'] as String? ?? 'draft',
                        tenggat: a['tenggat'] as String?,
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
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({
    required this.kelas,
    required this.mapel,
    required this.peran,
    required this.tahunAjaran,
  });

  final String kelas;
  final String mapel;
  final String peran;
  final String tahunAjaran;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: appSoftShadow,
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.school_outlined, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kelas,
                  style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  mapel,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          StatusBadge(
            label: peran,
            state: BadgeState.info,
          ),
        ],
      ),
    );
  }
}

class _MaterialRow extends StatelessWidget {
  const _MaterialRow({
    required this.judul,
    this.namaKelas,
    this.namaMapel,
    required this.dipublikasikan,
  });

  final String judul;
  final String? namaKelas;
  final String? namaMapel;
  final bool dipublikasikan;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            Icons.insert_drive_file_outlined,
            size: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  judul,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if ((namaKelas?.isNotEmpty ?? false) ||
                    (namaMapel?.isNotEmpty ?? false))
                  Text(
                    [
                      if (namaMapel?.isNotEmpty ?? false) namaMapel!,
                      if (namaKelas?.isNotEmpty ?? false) 'Kelas $namaKelas',
                    ].join(' · '),
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          StatusBadge(
            label: dipublikasikan ? 'Aktif' : 'Draf',
            state: dipublikasikan
                ? BadgeState.success
                : BadgeState.neutral,
          ),
        ],
      ),
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({
    required this.judul,
    required this.status,
    this.tenggat,
  });

  final String judul;
  final String status;
  final String? tenggat;

  @override
  Widget build(BuildContext context) {
    final badge = switch (status) {
      'dinilai' => (BadgeState.success, 'Tuntas'),
      'dikumpulkan' => (BadgeState.info, 'Dikerjakan'),
      'keterlambatan' => (BadgeState.danger, 'Terlambat'),
      'dipublikasikan' => (BadgeState.warning, 'Dipublikasikan'),
      _ => (BadgeState.neutral, status),
    };
    return Container(
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
            Icons.assignment_outlined,
            size: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  judul,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (tenggat != null)
                  Text(
                    'Tenggat: ${tenggat!.split('T')[0]}',
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          StatusBadge(label: badge.$2, state: badge.$1),
        ],
      ),
    );
  }
}
