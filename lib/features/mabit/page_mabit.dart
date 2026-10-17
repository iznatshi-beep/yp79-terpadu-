import 'package:flutter/material.dart';

import '../../../core/models/session_profile.dart';
import '../../../core/theme.dart';
import '../../../services/repositories.dart';
import '../../../widgets/app_states.dart';
import '../../../widgets/common.dart';

/// Halaman MABIT: kegiatan + rundown + mutaba'ah.
class PageMabit extends StatelessWidget {
  const PageMabit({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            'MABIT — Malam Bina Iman dan Takwa',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
        ),
        FutureBuilder<QueryResult<Map<String, dynamic>>>(
          future: Repos.mabitEvents(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: SkeletonRow(),
              );
            }
            final events = snap.data?.data ?? const [];
            if (events.isEmpty) {
              return const EmptyState(
                title: 'Belum ada kegiatan MABIT',
                message: 'Kegiatan MABIT akan tampil di sini.',
                icon: Icons.stars_outlined,
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
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
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
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
                                      color: AppColors.textPrimary),
                                ),
                              ),
                              StatusBadge(label: badge.$2, state: badge.$1),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Mulai: ${e['tanggal_mulai'] ?? '-'} · Selesai: ${e['tanggal_selesai'] ?? '-'}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                          if ((e['lokasi']?.toString() ?? '').isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    e['lokasi'].toString(),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if ((e['deskripsi']?.toString() ?? '').isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              e['deskripsi'].toString(),
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
