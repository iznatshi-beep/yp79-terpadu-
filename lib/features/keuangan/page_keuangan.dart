import 'package:flutter/material.dart';

import '../../../core/models/session_profile.dart';
import '../../../core/theme.dart';
import '../../../services/repositories.dart';
import '../../../widgets/app_states.dart';
import '../../../widgets/common.dart';

/// Halaman Keuangan: daftar biaya sekolah (tanpa transaksi online).
class PageKeuangan extends StatelessWidget {
  const PageKeuangan({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            'Pembiayaan Sekolah',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Text(
            'Daftar jenis biaya dan nominal yang ditetapkan sekolah. '
            'Pembayaran dilakukan di luar aplikasi (tunai/transfer).',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
        FutureBuilder<QueryResult<Map<String, dynamic>>>(
          future: Repos.financeCategories(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: AppStates.loading(rows: 3),
              );
            }
            final cats = snap.data?.data ?? const [];
            if (cats.isEmpty) {
              return const EmptyState(
                title: 'Belum ada jenis biaya',
                message: 'Jenis biaya akan ditambahkan oleh admin.',
                icon: Icons.receipt_long_outlined,
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: cats.length,
              itemBuilder: (context, i) {
                final c = cats[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Icon(Icons.receipt_long_outlined,
                            color: AppColors.success, size: 20),
                      ),
                      title: Text(
                        c['nama']?.toString() ?? c['kode']?.toString() ?? '-',
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                      subtitle: c['deskripsi'] == null ||
                              (c['deskripsi'] as String).isEmpty
                          ? null
                          : Text(
                              c['deskripsi'].toString(),
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary),
                            ),
                      trailing: StatusBadge(
                        label: c['aktif'] == true ? 'Aktif' : 'Nonaktif',
                        state: c['aktif'] == true
                            ? BadgeState.success
                            : BadgeState.neutral,
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
