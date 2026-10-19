import 'package:flutter/material.dart';

import '../../../core/models/session_profile.dart';
import '../../../core/theme.dart';
import '../../../services/repositories.dart';
import '../../../widgets/app_states.dart';
import '../../../widgets/common.dart';

/// Halaman MABIT lengkap: kegiatan, rundown, mutaba'ah, setoran hafalan.
/// Semua data nyata dari database (migrasi 0001-0012), tanpa dummy.
class PageMabit extends StatelessWidget {
  const PageMabit({super.key, this.profile});
  final SessionProfile? profile;

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
                Tab(text: 'Kegiatan'),
                Tab(text: 'Rundown'),
                Tab(text: "Mutaba'ah"),
                Tab(text: 'Hafalan'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(children: [
              _EventTab(),
              _RundownTab(),
              _MutabaahTab(profile: profile),
              _HafalanTab(profile: profile),
            ]),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 1: Kegiatan MABIT (semua role bisa lihat)
// ---------------------------------------------------------------------------
class _EventTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QueryResult<RowData>>(
      future: Repos.mabitEvents(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(16), child: SkeletonRow());
        }
        final events = snap.data?.data ?? const <RowData>[];
        if (events.isEmpty) {
          return const EmptyState(
            title: 'Belum ada kegiatan MABIT',
            message: 'Kegiatan MABIT akan tampil di sini.',
            icon: Icons.stars_outlined,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(18),
          itemCount: events.length,
          itemBuilder: (context, i) {
            final e = events[i];
            final status = e['status']?.toString() ?? 'aktif';
            final badge = switch (status) {
              'aktif' => (BadgeState.success, 'Aktif'),
              'selesai' => (BadgeState.neutral, 'Selesai'),
              _ => (BadgeState.danger, status),
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  boxShadow: appSoftShadow,
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            e['nama_kegiatan']?.toString() ?? '-',
                            style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink),
                          ),
                        ),
                        StatusBadge(label: badge.$2, state: badge.$1),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Mulai: ${e['tanggal_mulai']?.toString().split('T')[0] ?? '-'}'
                      ' - Selesai: ${e['tanggal_selesai']?.toString().split('T')[0] ?? '-'}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    if ((e['lokasi']?.toString() ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Lokasi: ${e['lokasi']}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// TAB RUNDOWN
// ---------------------------------------------------------------------------
class _RundownTab extends StatelessWidget {
  const _RundownTab();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QueryResult<RowData>>(
      future: () async {
        final events = await Repos.mabitEvents();
        final eventId =
            events.data.isNotEmpty ? events.data.first['id']?.toString() : null;
        if (eventId == null || eventId.isEmpty) {
          return const QueryResult<RowData>(data: []);
        }
        return Repos.mabitRundown(eventId);
      }(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(16), child: SkeletonRow());
        }
        final items = snap.data?.data ?? const <RowData>[];
        if (items.isEmpty) {
          return const EmptyState(
            title: 'Belum ada rundown',
            message: 'Rundown kegiatan MABIT akan tampil di sini.',
            icon: Icons.schedule,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(18),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final r = items[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  boxShadow: appSoftShadow,
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Text(r['jam']?.toString() ?? '-',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r['aktivitas']?.toString() ?? '-',
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink)),
                          if ((r['keterangan']?.toString() ?? '').isNotEmpty)
                            Text(r['keterangan'].toString(),
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// TAB MUTABA'AH
// ---------------------------------------------------------------------------
class _MutabaahTab extends StatelessWidget {
  const _MutabaahTab();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QueryResult<RowData>>(
      future: Repos.mutabaahSaya(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(16), child: SkeletonRow());
        }
        final entries = snap.data?.data ?? const <RowData>[];
        if (entries.isEmpty) {
          return const EmptyState(
            title: 'Belum ada jurnal mutabaah',
            message:
                'Checklist ibadah harian (dzikir, shalat sunnah, bacaan Al-Quran) '
                'yang Anda isi akan tampil di sini.',
            icon: Icons.auto_awesome_outlined,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(18),
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final e = entries[i];
            final checklist =
                (e['checklist'] as Map?)?.cast<String, dynamic>() ?? {};
            final diverifikasi = e['diverifikasi'] == true;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  boxShadow: appSoftShadow,
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(e['tanggal']?.toString() ?? '-',
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink)),
                        ),
                        StatusBadge(
                            label: diverifikasi ? 'Terverifikasi' : 'Belum',
                            state: diverifikasi
                                ? BadgeState.success
                                : BadgeState.neutral),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...checklist.entries.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                c.value == true
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                size: 18,
                                color: c.value == true
                                    ? AppColors.success
                                    : AppColors.border,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(c.key,
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textPrimary)),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// TAB HAFALAN
// ---------------------------------------------------------------------------
class _HafalanTab extends StatelessWidget {
  const _HafalanTab();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QueryResult<RowData>>(
      future: Repos.memorization(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(16), child: SkeletonRow());
        }
        final items = snap.data?.data ?? const <RowData>[];
        if (items.isEmpty) {
          return const EmptyState(
            title: 'Belum ada setoran hafalan',
            message: 'Capaian hafalan (Juz Amma/doa) yang diverifikasi guru '
                'pembimbing akan tampil di sini.',
            icon: Icons.menu_book_outlined,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(18),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final m = items[i];
            final status = m['status']?.toString() ?? 'menunggu';
            final badge = switch (status) {
              'disetujui' || 'terverifikasi' =>
                (BadgeState.success, 'Terverifikasi'),
              'ditolak' => (BadgeState.danger, 'Ditolak'),
              _ => (BadgeState.warning, 'Menunggu'),
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  boxShadow: appSoftShadow,
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(m['judul'] ?? '-',
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink)),
                        ),
                        StatusBadge(label: badge.$2, state: badge.$1),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${m['kategori'] ?? '-'} · capaian: ${m['capaian'] ?? '-'}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                    if ((m['catatan']?.toString() ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Catatan: ${m['catatan']}',
                            style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
  }
}
}
