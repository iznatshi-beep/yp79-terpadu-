import 'package:flutter/material.dart';

import '../../../core/models/session_profile.dart';
import '../../../core/theme.dart';
import '../../../services/repositories.dart';
import '../../../widgets/app_states.dart';
import '../../../widgets/dashboard_widgets.dart';
import '../../../widgets/quick_actions.dart';
import '../izin/izin_page.dart';

/// Dashboard Siswa: presensi hari ini + jadwal + tugas + ujian.
class SiswaDashboard extends StatelessWidget {
  const SiswaDashboard({super.key, required this.profile});
  final SessionProfile profile;

  @override
  Widget build(BuildContext context) {
    final studentId = profile.studentId;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        FutureBuilder<QueryResult<Map<String, dynamic>>>(
          future: Repos.attendance(studentId: studentId),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: SkeletonRow(),
              );
            }
            final recs = snap.data?.data ?? const [];
            final today = DateTime.now().toIso8601String().substring(0, 10);
            final hadirHariIni = recs
                .any((r) => (r['tanggal'] as String?)?.startsWith(today) == true &&
                    (r['status'] as String?) == 'hadir');
            return Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kartu hero ala showcase TaskFlow: biru penuh + teks putih.
                  HeroSummaryCard(
                    greeting: 'Assalamualaikum, ${profile.name ?? 'Siswa'} 👋',
                    title: 'Presensi hari ini',
                    value: hadirHariIni ? 'Hadir' : 'Belum',
                    subtitle: hadirHariIni
                        ? 'Presensi tercatat dengan benar. Semangat belajarnya!'
                        : 'Presensi dicatat oleh guru atau sistem QR.',
                    icon: hadirHariIni
                        ? Icons.check_circle_outline
                        : Icons.access_time_rounded,
                  ),
                  const SizedBox(height: 18),
                  const SectionHeader(title: 'Aksi Cepat'),
                  const SizedBox(height: 6),
                  ModulAksiGrid(
                    items: [
                      ModulAksi(
                        label: 'Ajukan Izin',
                        icon: Icons.event_busy_outlined,
                        builder: (_) => IzinPage(profile: profile),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Ringkasan presensi 7 hari terakhir (data nyata, bukan
                  // angka hardcode).
                  if (recs.isNotEmpty) ...[
                    const SectionHeader(title: 'Rekap 7 Hari Terakhir'),
                    const SizedBox(height: 4),
                    _RekapPresensiRow(records: recs),
                  ],
                ],
              ),
            );
          },
        ),
        FutureBuilder<QueryResult<Map<String, dynamic>>>(
          future: Repos.leaves(studentId: studentId),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(height: 10);
            }
            final leaves = snap.data?.data ?? const [];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Pengajuan Izin & Sakit'),
                  if (leaves.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: EmptyState(
                        title: 'Belum ada pengajuan izin',
                        message: 'Pengajuan izin/sakit Anda akan tampil di sini.',
                        icon: Icons.assignment_return_outlined,
                      ),
                    )
                  else
                    for (final l in leaves)
                      _LeaveTile(
                        jenis: l['jenis'] as String? ?? '',
                        mulai: l['mulai'] as String?,
                        status: l['status'] as String? ?? '',
                        alasan: l['alasan'] as String?,
                      ),
                ],
              ),
            );
          },
        ),
        FutureBuilder<QueryResult<Map<String, dynamic>>>(
          future: Repos.exams(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(height: 10);
            }
            final exams = snap.data?.data ?? const [];
            final aktif = exams
                .where((e) => (e['status'] as String?) == 'aktif')
                .toList();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Ujian CBT Mendatang'),
                  if (aktif.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: EmptyState(
                        title: 'Tidak ada ujian aktif',
                        message: 'Ujian yang sedang berlangsung akan tampil di sini.',
                        icon: Icons.assignment_outlined,
                      ),
                    )
                  else
                    for (final e in aktif)
                      _ExamRow(
                        judul: e['judul'] as String? ?? '',
                        mulai: e['mulai'] as String?,
                        selesai: e['selesai'] as String?,
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

/// Baris rekap presensi 7 hari terakhir: hitung dari data sungguhan.
class _RekapPresensiRow extends StatelessWidget {
  const _RekapPresensiRow({required this.records});
  final List<Map<String, dynamic>> records;

  @override
  Widget build(BuildContext context) {
    final batas = DateTime.now().subtract(const Duration(days: 7));
    final mingguIni = [
      for (final r in records)
        if (DateTime.tryParse(r['tanggal']?.toString() ?? '') != null &&
            DateTime.parse(r['tanggal'].toString()).isAfter(batas))
          r
    ];

    final hadir = mingguIni.where((r) => r['status'] == 'hadir').length;
    final terlambat =
        mingguIni.where((r) => r['status'] == 'terlambat').length;
    final izin = mingguIni
        .where((r) => r['status'] == 'izin' || r['status'] == 'sakit')
        .length;
    final alpa = mingguIni.where((r) => r['status'] == 'alpa').length;

    return Row(
      children: [
        _KotakRekap(label: 'Hadir', value: '$hadir'),
        _KotakRekap(label: 'Terlambat', value: '$terlambat'),
        _KotakRekap(label: 'Alpa', value: '$alpa'),
        _KotakRekap(label: 'Izin/Sakit', value: '$izin'),
      ],
    );
  }
}

/// Satu kotak rekap (Hadir / Terlambat / Alpa / Izin) dengan warna status.
class _KotakRekap extends StatelessWidget {
  const _KotakRekap({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final warna = switch (label) {
      'Hadir' => AppColors.success,
      'Terlambat' => AppColors.warning,
      'Alpa' => AppColors.danger,
      _ => AppColors.primary,
    };
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: appSoftShadow,
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: warna)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _LeaveTile extends StatelessWidget {
  const _LeaveTile({
    required this.jenis,
    this.mulai,
    required this.status,
    this.alasan,
  });

  final String jenis;
  final String? mulai;
  final String status;
  final String? alasan;

  @override
  Widget build(BuildContext context) {
    final badge = switch (status) {
      'disetujui' => (BadgeState.success, 'Disetujui'),
      'ditolak' => (BadgeState.danger, 'Ditolak'),
      'diproses' => (BadgeState.warning, 'Diproses'),
      _ => (BadgeState.info, 'Diajukan'),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Izin $jenis — ${mulai ?? ''}',
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                if (alasan != null && alasan!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    alasan!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          StatusBadge(label: badge.$2, state: badge.$1),
        ],
      ),
    );
  }
}

class _ExamRow extends StatelessWidget {
  const _ExamRow({
    required this.judul,
    this.mulai,
    this.selesai,
  });

  final String judul;
  final String? mulai;
  final String? selesai;

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
          Icon(Icons.assignment_outlined, size: 20, color: AppColors.primary),
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
                const SizedBox(height: 2),
                Text(
                  'Mulai: ${mulai?.split('T')[0] ?? '-'}  ·  Selesai: ${selesai?.split('T')[0] ?? '-'}',
                  style:
                      const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          StatusBadge(label: 'Aktif', state: BadgeState.success),
        ],
      ),
    );
  }
}
