import 'package:flutter/material.dart';

import '../../../core/models/session_profile.dart';
import '../../../core/theme.dart';
import '../../../services/repositories.dart';
import '../../../widgets/app_states.dart';
import '../../../widgets/common.dart';

/// Halaman LMS: materi, tugas, dan pengumpulan.
class LmsPage extends StatefulWidget {
  const LmsPage({super.key});

  @override
  State<LmsPage> createState() => _LmsPageState();
}

class _LmsPageState extends State<LmsPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _TabPill(
                label: 'Materi',
                active: _tab == 0,
                onTap: () => setState(() => _tab = 0),
              ),
              const SizedBox(width: 8),
              _TabPill(
                label: 'Tugas',
                active: _tab == 1,
                onTap: () => setState(() => _tab = 1),
              ),
              const SizedBox(width: 8),
              _TabPill(
                label: 'Pengumpulan',
                active: _tab == 2,
                onTap: () => setState(() => _tab = 2),
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (_tab) {
            0 => _MateriList(),
            1 => _TugasList(),
            2 => _PengumpulanList(),
            _ => const SizedBox(),
          },
        ),
      ],
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _MateriList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QueryResult<Map<String, dynamic>>>(
      future: Repos.materials(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: AppStates.loading(rows: 4),
          );
        }
        final mats = snap.data?.data ?? const [];
        if (mats.isEmpty) {
          return const EmptyState(
            title: 'Belum ada materi',
            message: 'Materi pembelajaran LMS akan tampil di sini.',
            icon: Icons.menu_book_outlined,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: mats.length,
          itemBuilder: (context, i) {
            final m = mats[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.insert_drive_file_outlined,
                        color: AppColors.primary, size: 20),
                  ),
                  title: Text(
                    m['judul']?.toString() ?? '-',
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    [
                      if (m['subjects'] is Map && m['subjects'] != null)
                        (m['subjects'] as Map)['nama']?.toString() ?? '',
                      if (m['classes'] is Map && m['classes'] != null)
                        'Kelas ${((m['classes'] as Map)['nama'])}',
                    ].join(' · '),
                    style:
                        const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                  trailing: StatusBadge(
                    label: (m['dipublikasikan'] as bool? ?? false)
                        ? 'Aktif'
                        : 'Draf',
                    state: (m['dipublikasikan'] as bool? ?? false)
                        ? BadgeState.success
                        : BadgeState.neutral,
                  ),
                  onTap: () {
                    if (m['file_url'] != null) {
                      showToast(context, 'Membuka materi… (URL: ${m['file_url']})');
                    } else {
                      showToast(context, 'Materi ini belum memiliki file.');
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TugasList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QueryResult<Map<String, dynamic>>>(
      future: Repos.assignments(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: AppStates.loading(rows: 4),
          );
        }
        final asgs = snap.data?.data ?? const [];
        if (asgs.isEmpty) {
          return const EmptyState(
            title: 'Belum ada tugas',
            message: 'Tugas dari guru akan tampil di sini.',
            icon: Icons.assignment_outlined,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: asgs.length,
          itemBuilder: (context, i) {
            final a = asgs[i];
            final status = a['status']?.toString() ?? 'draft';
            final badge = switch (status) {
              'dinilai' => (BadgeState.success, 'Tuntas'),
              'dikumpulkan' => (BadgeState.info, 'Dikerjakan'),
              'keterlambatan' => (BadgeState.danger, 'Terlambat'),
              'dipublikasikan' => (BadgeState.warning, 'Dibuka'),
              _ => (BadgeState.neutral, status),
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  title: Text(
                    a['judul']?.toString() ?? '-',
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    'Tenggat: ${a['tenggat']?.toString().split('T')[0] ?? '-'}',
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                  trailing: StatusBadge(label: badge.$2, state: badge.$1),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PengumpulanList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QueryResult<Map<String, dynamic>>>(
      future: Repos.submissions(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: AppStates.loading(rows: 4),
          );
        }
        final subs = snap.data?.data ?? const [];
        if (subs.isEmpty) {
          return const EmptyState(
            title: 'Belum ada pengumpulan',
            message: 'Hasil tugas Anda akan tampil di sini.',
            icon: Icons.assignment_return_outlined,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: subs.length,
          itemBuilder: (context, i) {
            final s = subs[i];
            final nilai = s['nilai'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  title: Text(
                    (s['assignments'] is Map && s['assignments'] != null)
                        ? ((s['assignments'] as Map)['judul']?.toString() ?? '-')
                        : '-',
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    'Dikumpulkan: ${s['waktu_kumpul']?.toString().split('T')[0] ?? '-'}',
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                  trailing: nilai == null
                      ? const StatusBadge(
                          label: 'Menunggu',
                          state: BadgeState.neutral,
                        )
                      : Text(
                          nilai.toString(),
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.success),
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
