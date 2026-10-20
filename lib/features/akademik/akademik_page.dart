import 'package:flutter/material.dart';

import '../../../core/models/session_profile.dart';
import '../../../core/theme.dart';
import '../../../services/repositories.dart';
import '../../../widgets/app_states.dart';
import 'rekap_presensi_page.dart';

/// Halaman Akademik: kelas, jadwal, presensi, nilai.
class AkademikPage extends StatefulWidget {
  const AkademikPage({super.key, this.profile});

  final SessionProfile? profile;

  @override
  State<AkademikPage> createState() => _AkademikPageState();
}

class _AkademikPageState extends State<AkademikPage> {
  // Field `_tab` dihapus: tidak pernah dibaca (analyzer: unused_field).
  // Navigasi tab ditangani DefaultTabController.

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Kelas & Siswa'),
                Tab(text: 'Jadwal'),
                Tab(text: 'Presensi'),
                Tab(text: 'Nilai'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _KelasTab(),
                _JadwalTab(),
                _PresensiTab(),
                _NilaiTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KelasTab extends StatelessWidget {
  const _KelasTab();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QueryResult<Map<String, dynamic>>>(
      future: Repos.classes(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: SkeletonRow(),
          );
        }
        final classes = snap.data?.data ?? const [];
        if (classes.isEmpty) {
          return const EmptyState(
            title: 'Belum ada kelas',
            message: 'Admin belum membuat data kelas.',
            icon: Icons.school_outlined,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(18),
          itemCount: classes.length,
          itemBuilder: (context, i) {
            final c = classes[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ClassCard(
                nama: c['nama'] as String? ?? '',
                jenjang: c['jenjang'] as String? ?? '',
                tahun: c['tahun_ajaran'] as String? ?? '',
              ),
            );
          },
        );
      },
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.nama,
    required this.jenjang,
    required this.tahun,
  });

  final String nama;
  final String jenjang;
  final String tahun;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(Icons.class_outlined,
                  size: 22, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nama,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text('$jenjang · $tahun',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JadwalTab extends StatelessWidget {
  const _JadwalTab();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QueryResult<Map<String, dynamic>>>(
      future: Repos.schedules(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: SkeletonRow(),
          );
        }
        final schedules = snap.data?.data ?? const [];
        if (schedules.isEmpty) {
          return const EmptyState(
            title: 'Jadwal belum tersedia',
            message: 'Admin belum mengatur jadwal kelas.',
            icon: Icons.schedule,
          );
        }
        final byDay = <String, List<dynamic>>{};
        for (final s in schedules) {
          final day = s['hari'] as String? ?? '';
          byDay.putIfAbsent(day, () => []).add(s);
        }
        return ListView.builder(
          padding: const EdgeInsets.all(18),
          itemCount: byDay.length,
          itemBuilder: (context, i) {
            final day = byDay.keys.elementAt(i);
            final items = byDay[day]!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            day,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary),
                          ),
                          const Spacer(),
                          StatusBadge(
                            label: '${items.length} mapel',
                            state: BadgeState.info,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final s in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Text(
                                '${s['jam_mulai']}–${s['jam_selesai']}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  (s['subjects'] is Map && s['subjects'] != null)
                                      ? '${(s['subjects'] as Map)['kode'] ?? ''} — ${((s['subjects'] as Map)['nama'])}'
                                      : '-',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary),
                                ),
                              ),
                              if (s['ruang'] != null &&
                                  (s['ruang'] as String).isNotEmpty)
                                Text(
                                  'Ruang ${s['ruang']}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PresensiTab extends StatelessWidget {
  const _PresensiTab();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QueryResult<Map<String, dynamic>>>(
      future: Repos.attendanceToday(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: SkeletonRow(),
          );
        }
        final records = snap.data?.data ?? const [];
        // Tombol Rekap Presensi selalu tampil di atas daftar.
        return Stack(
          children: [
            ListView.builder(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              itemCount: records.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const _RekapGate(),
                        ),
                      ),
                      icon: const Icon(Icons.assessment_outlined, size: 18),
                      label: const Text('Rekap Harian / Mingguan / Bulanan'),
                    ),
                  );
                }
                final r = records[i - 1];
                final status = r['status'] as String? ?? '';
            final badge = switch (status) {
              'hadir' => (BadgeState.success, 'Hadir'),
              'terlambat' => (BadgeState.warning, 'Terlambat'),
              'izin' => (BadgeState.info, 'Izin'),
              'sakit' => (BadgeState.warning, 'Sakit'),
              'alpa' => (BadgeState.danger, 'Alpa'),
              _ => (BadgeState.neutral, status),
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  title: Text(
                    r['jam_checkin']?.toString().split('T')[0] ?? '',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    r['metode']?.toString().toUpperCase() ?? '',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  trailing: StatusBadge(label: badge.$2, state: badge.$1),
                ),
              ),
            );
                },
              ),
          ],
        );
      },
    );
  }
}

/// Gate: rekap presensi butuh profile — diambil dari AuthGate via
/// SessionProfile statik. Karena AkademikPage tidak menerima profile,
/// rekap memakai kelas yang dipilih pengguna di halaman rekap.
class _RekapGate extends StatelessWidget {
  const _RekapGate();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Memuat…')),
    );
  }
}

class _NilaiTab extends StatelessWidget {
  const _NilaiTab();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QueryResult<Map<String, dynamic>>>(
      future: Repos.grades(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: SkeletonRow(),
          );
        }
        final grades = snap.data?.data ?? const [];
        if (grades.isEmpty) {
          return const EmptyState(
            title: 'Belum ada nilai',
            message: 'Nilai akan muncul setelah guru menginput.',
            icon: Icons.grade_outlined,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(18),
          itemCount: grades.length,
          itemBuilder: (context, i) {
            final g = grades[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  title: Text(
                    ((g['subjects'] is Map && g['subjects'] != null)
                            ? '${(g['subjects'] as Map)['kode'] ?? ''} ${((g['subjects'] as Map)['nama'])}'
                            : '-'),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    g['kategori']?.toString() ?? '',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  trailing: Text(
                    g['nilai'].toString(),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
