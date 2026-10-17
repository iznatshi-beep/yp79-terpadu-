import 'package:flutter/material.dart';

import '../../../core/models/session_profile.dart';
import '../../../core/theme.dart';
import '../../../services/repositories.dart';
import '../../../widgets/app_states.dart';
import '../../../widgets/common.dart';

/// Halaman CBT: daftar ujian + hasil.
class CbtPage extends StatelessWidget {
  const CbtPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ujian CBT',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pilih ujian untuk melihat detail dan memulai.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        FutureBuilder<QueryResult<Map<String, dynamic>>>(
          future: Repos.exams(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: AppStates.loading(rows: 3),
              );
            }
            final exams = snap.data?.data ?? const [];
            if (exams.isEmpty) {
              return const EmptyState(
                title: 'Belum ada ujian',
                message: 'Ujian CBT akan tampil di sini.',
                icon: Icons.assignment_outlined,
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: exams.length,
              itemBuilder: (context, i) {
                final e = exams[i];
                final status = e['status']?.toString() ?? 'draft';
                final badge = switch (status) {
                  'aktif' => (BadgeState.success, 'Aktif'),
                  'selesai' => (BadgeState.neutral, 'Selesai'),
                  'dipublikasikan' => (BadgeState.info, 'Dipublikasikan'),
                  _ => (BadgeState.warning, 'Draf'),
                };
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      title: Text(
                        e['judul']?.toString() ?? '-',
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                      subtitle: Text(
                        'Mulai: ${e['mulai']?.toString().split('T')[0] ?? '-'}  ·  Selesai: ${e['selesai']?.toString().split('T')[0] ?? '-'}',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                      trailing: StatusBadge(label: badge.$2, state: badge.$1),
                      onTap: () => _openExam(context, e),
                    ),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 10),
        FutureBuilder<QueryResult<Map<String, dynamic>>>(
          future: Repos.examAttempts(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(height: 10);
            }
            final attempts = snap.data?.data ?? const [];
            if (attempts.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(14),
                child: EmptyState(
                  title: 'Belum ada hasil ujian',
                  message: 'Hasil CBT Anda akan tampil di sini.',
                  icon: Icons.grade_outlined,
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: attempts.length,
              itemBuilder: (context, i) {
                final a = attempts[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      title: Text(
                        (a['exams'] is Map && a['exams'] != null)
                            ? ((a['exams'] as Map)['judul']?.toString() ?? '-')
                            : '-',
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                      subtitle: Text(
                        'Percobaan ${a['percobaan'] ?? 1} · ${a['selesai']?.toString().split('T')[0] ?? 'berlangsung'}',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                      trailing: a['nilai_pilihan'] == null
                          ? const StatusBadge(
                              label: 'Menunggu',
                              state: BadgeState.neutral)
                          : Text(
                              a['nilai_pilihan'].toString(),
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
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  void _openExam(BuildContext context, Map<String, dynamic> e) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ExamDetailPage(exam: e),
      ),
    );
  }
}

class _ExamDetailPage extends StatelessWidget {
  const _ExamDetailPage({required this.exam});

  final Map<String, dynamic> exam;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(exam['judul']?.toString() ?? 'Detail Ujian'),
      ),
      body: FutureBuilder<QueryResult<Map<String, dynamic>>>(
        future: Repos.examQuestions(exam['id'] as String),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: AppStates.loading(rows: 4),
            );
          }
          final qs = snap.data?.data ?? const [];
          if (qs.isEmpty) {
            return const EmptyState(
              title: 'Belum ada soal',
              message: 'Soal ujian akan tampil di sini.',
              icon: Icons.list_outlined,
            );
          }
          final status = exam['status']?.toString() ?? 'draft';
          final kunciTerkunci = exam['kunci_terkunci'] as bool? ?? true;
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: qs.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      StatusBadge(
                        label: status.toUpperCase(),
                        state: status == 'aktif'
                            ? BadgeState.success
                            : BadgeState.neutral,
                      ),
                      const Spacer(),
                      if (status == 'aktif')
                        FilledButton(
                          onPressed: () => _startExam(context),
                          child: const Text('Mulai Ujian'),
                        ),
                    ],
                  ),
                );
              }
              final q = qs[i - 1];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusBadge(
                            label:
                                (q['tipe'] == 'esai' ? 'Esai' : 'Pilihan Ganda'),
                            state: BadgeState.info,
                          ),
                          const Spacer(),
                          Text(
                            'Skor: ${q['skor'] ?? 0}',
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        q['pertanyaan']?.toString() ?? '',
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                      ),
                      if (q['tipe'] == 'pilihan') ...[
                        const SizedBox(height: 8),
                        for (final (label, val) in [
                          ('A', 'A'),
                          ('B', 'B'),
                          ('C', 'C'),
                          ('D', 'D')
                        ]) ...[
                          if (q['opsi_$val'.toUpperCase()] != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Text('$val. ',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13)),
                                  Expanded(
                                    child: Text(
                                        q['opsi_$val'.toUpperCase()]
                                                .toString() ??
                                            ''),
                                  ),
                                ],
                              ),
                            ),
                        ],
                        // Kunci hanya ditampilkan jika terverifikasi tidak tersembunyi
                        if (!kunciTerkunci || status == 'selesai') ...[
                          const SizedBox(height: 8),
                          Text(
                            'Kunci: ${q['kunci'] ?? '-'}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.success,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _startExam(BuildContext context) {
    showToast(context, 'Menjalankan ujian…', durasi: 2);
  }
}
