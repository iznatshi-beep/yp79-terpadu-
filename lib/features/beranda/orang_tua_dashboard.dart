import 'package:flutter/material.dart';

import '../../../core/models/session_profile.dart';
import '../../../core/theme.dart';
import '../../../services/repositories.dart';
import '../../../widgets/app_states.dart';
import '../../../widgets/dashboard_widgets.dart';
import '../../../widgets/quick_actions.dart';
import '../izin/izin_page.dart';
import '../izin/consent_page.dart';
import '../izin/appointment_page.dart';

/// Dashboard Orang Tua: memilih anak → presensi + nilai + pembiayaan anak.
class OrangTuaDashboard extends StatelessWidget {
  const OrangTuaDashboard({super.key, required this.profile});
  final SessionProfile profile;

  @override
  Widget build(BuildContext context) {
    final anakIds = profile.parentStudentIds;
    if (anakIds.isEmpty) {
      return const EmptyState(
        title: 'Belum ada anak terhubung',
        message:
            'Hubungan Anda dengan siswa belum diverifikasi. '
            'Silakan hubungi admin sekolah untuk verifikasi.',
        icon: Icons.supervisor_account_outlined,
      );
    }
    return _AnakList(profile: profile, anakIds: anakIds);
  }
}

class _AnakList extends StatefulWidget {
  const _AnakList({required this.profile, required this.anakIds});
  final SessionProfile profile;
  final List<String> anakIds;

  @override
  State<_AnakList> createState() => _AnakListState();
}

class _AnakListState extends State<_AnakList> {
  int _index = 0;
  Future<QueryResult<RowData>>? _futureAnak;

  @override
  void initState() {
    super.initState();
    _futureAnak = Repos.anakSaya();
  }

  @override
  Widget build(BuildContext context) {
    final anakId = widget.anakIds[_index];
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        FutureBuilder<QueryResult<RowData>>(
          future: _futureAnak,
          builder: (context, snapAnak) {
            final anak = snapAnak.data?.data ?? const <RowData>[];
            // Nama anak diambil dari RPC anak_saya (relasi wajib sudah
            // diverifikasi admin). Saat belum termuat, fallback ke "Anak N".
            String namaAnak(int i) =>
                i < anak.length
                    ? (anak[i]['nama']?.toString().isNotEmpty ?? false)
                        ? anak[i]['nama'].toString()
                        : 'Anak ${i + 1}'
                    : 'Anak ${i + 1}';
            // clamp() pada int mengembalikan num, sedangkan indeks list
            // butuh int -> konversi eksplisit.
            final iNow = widget.anakIds.isEmpty
                ? 0
                : _index.clamp(0, widget.anakIds.length - 1).toInt();
            return Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HeroSummaryCard(
                    greeting:
                        'Assalamualaikum, ${widget.profile.name ?? 'Orang Tua'} 👋',
                    title: anak.isEmpty
                        ? 'Pantau anak Anda'
                        : 'Pantau ${namaAnak(iNow)}',
                    value: namaAnak(iNow),
                    subtitle: 'Presensi, nilai, dan pembiayaan anak tampil di bawah.',
                    icon: Icons.family_restroom_rounded,
                  ),
                  const SizedBox(height: 16),
                  const SectionHeader(title: 'Pilih Anak'),
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < widget.anakIds.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(namaAnak(i)),
                              selected: _index == i,
                              onSelected: (_) => setState(() => _index = i),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const SectionHeader(title: 'Aksi Cepat'),
                  const SizedBox(height: 6),
                  ModulAksiGrid(
                    items: [
                      ModulAksi(
                        label: 'Ajukan Izin',
                        icon: Icons.event_busy_outlined,
                        builder: (_) => IzinPage(profile: widget.profile),
                      ),
                      ModulAksi(
                        label: 'Persetujuan Ortu',
                        icon: Icons.fact_check_outlined,
                        builder: (_) => ConsentPage(profile: widget.profile),
                      ),
                      ModulAksi(
                        label: 'Jadwal Pertemuan',
                        icon: Icons.schedule_send_outlined,
                        builder: (_) =>
                            AppointmentPage(profile: widget.profile),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const SectionHeader(title: 'Presensi Anak Terakhir'),
                ],
              ),
            );
          },
        ),
        FutureBuilder<QueryResult<RowData>>(
          future: Repos.attendance(studentId: anakId),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(18),
                child: SkeletonRow(),
              );
            }
            final recs = snap.data?.data ?? const <RowData>[];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  if (recs.isEmpty)
                    const EmptyState(
                      title: 'Belum ada riwayat presensi',
                      message: 'Data presensi anak akan tampil di sini.',
                      icon: Icons.fact_check_outlined,
                    )
                  else
                    for (final r in recs.take(10))
                      _PresensiRow(
                        tanggal: r['tanggal'] as String?,
                        status: r['status'] as String?,
                        metode: r['metode'] as String?,
                      ),
                ],
              ),
            );
          },
        ),
        FutureBuilder<QueryResult<RowData>>(
          future: Repos.grades(studentId: anakId),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(height: 10);
            }
            final grades = snap.data?.data ?? const <RowData>[];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Nilai Anak (Terakhir)'),
                  if (grades.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(18),
                      child: EmptyState(
                        title: 'Belum ada nilai',
                        message: 'Nilai yang dipublikasikan akan tampil di sini.',
                        icon: Icons.grade_outlined,
                      ),
                    )
                  else
                    for (final g in grades.take(8))
                      _GradeRow(
                        mapel:
                            '${(g['subjects'] as Map?)?['kode'] as String? ?? ''}'
                            ' — '
                            '${(g['subjects'] as Map?)?['nama'] as String? ?? ''}',
                        kategori: g['kategori'] as String? ?? '',
                        nilai: g['nilai'] == null
                            ? '-'
                            : (g['nilai'] as num).toString(),
                      ),
                ],
              ),
            );
          },
        ),
        FutureBuilder<QueryResult<RowData>>(
          future: Repos.financeItems(studentId: anakId),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(height: 10);
            }
            final items = snap.data?.data ?? const <RowData>[];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Pembiayaan Sekolah Anak'),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(18),
                      child: EmptyState(
                        title: 'Belum ada data pembiayaan',
                        message:
                            'Jenis biaya dan nominal akan ditampilkan di sini.',
                        icon: Icons.receipt_long_outlined,
                      ),
                    )
                  else
                    for (final f in items)
                      _FinanceRow(
                        nama: ((f['finance_categories'] as Map?)?['nama']
                                as String?) ??
                            'Biaya',
                        nominal: f['nominal'] as num? ?? 0,
                        semester: f['semester'] as String? ?? '',
                        tahun: f['tahun_ajaran'] as String? ?? '',
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

class _PresensiRow extends StatelessWidget {
  const _PresensiRow({
    this.tanggal,
    this.status,
    this.metode,
  });

  final String? tanggal;
  final String? status;
  final String? metode;

  @override
  Widget build(BuildContext context) {
    final badge = switch (status) {
      'hadir' => (BadgeState.success, 'Hadir'),
      'terlambat' => (BadgeState.warning, 'Terlambat'),
      'izin' => (BadgeState.info, 'Izin'),
      'sakit' => (BadgeState.warning, 'Sakit'),
      'alpa' => (BadgeState.danger, 'Alpa'),
      _ => (BadgeState.neutral, status ?? '?'),
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
        children: [
          Icon(Icons.fact_check_outlined,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tanggal ?? '-',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (metode != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                metode!.toUpperCase(),
                style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5),
              ),
            ),
          StatusBadge(label: badge.$2, state: badge.$1),
        ],
      ),
    );
  }
}

class _GradeRow extends StatelessWidget {
  const _GradeRow({
    required this.mapel,
    required this.kategori,
    required this.nilai,
  });

  final String mapel;
  final String kategori;
  final String nilai;

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
        children: [
          Icon(Icons.grade_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mapel,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(label: kategori, state: BadgeState.neutral),
          const SizedBox(width: 10),
          Text(
            nilai,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _FinanceRow extends StatelessWidget {
  const _FinanceRow({
    required this.nama,
    required this.nominal,
    required this.semester,
    required this.tahun,
  });

  final String nama;
  final num nominal;
  final String semester;
  final String tahun;

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
          Icon(Icons.receipt_long_outlined,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nama,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Semester $semester · $tahun',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            nominal == 0 ? '-' : Rp.format(nominal),
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class Rp {
  static String format(num n) {
    final s = n.toString();
    final parts = s.split('.');
    final intPart = parts[0];
    final dec = parts.length > 1 ? '.${parts[1]}' : '';
    final buffer = intPart.split('').toList().reversed.toList();
    final sb = StringBuffer();
    for (var i = 0; i < buffer.length; i++) {
      if (i > 0 && i % 3 == 0) sb.write('.');
      sb.write(buffer[i]);
    }
    final formatted = sb.toString().split('').reversed.join();
    return 'Rp $formatted$dec';
  }
}
