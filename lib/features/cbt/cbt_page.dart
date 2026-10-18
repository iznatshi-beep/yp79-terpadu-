import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../services/repositories.dart';
import '../../../widgets/app_states.dart';
import '../../../widgets/common.dart';
import '../../../widgets/dashboard_widgets.dart';
import 'exam_take_page.dart';

/// Halaman CBT: daftar ujian, pengerjaan ujian, dan hasil.
class CbtPage extends StatefulWidget {
  const CbtPage({super.key});

  @override
  State<CbtPage> createState() => _CbtPageState();
}

class _CbtPageState extends State<CbtPage> {
  /// Dinaikkan setiap kembali dari halaman ujian agar daftar + hasil
  /// benar-benar diambil ulang dari database (bukan cache tampilan).
  int _reload = 0;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const Padding(
          padding: EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ujian CBT',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
              ),
              SizedBox(height: 4),
              Text(
                'Pilih ujian untuk melihat detail dan memulai.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        FutureBuilder<QueryResult<RowData>>(
          key: ValueKey('exams-$_reload'),
          future: Repos.exams(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: SkeletonRow(),
              );
            }
            if (snap.data?.error != null) {
              return Padding(
                padding: const EdgeInsets.all(14),
                child: ErrorState(message: snap.data!.error!),
              );
            }
            final exams = snap.data?.data ?? const <RowData>[];
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: SectionHeader(title: 'Hasil Ujian'),
        ),
        FutureBuilder<QueryResult<RowData>>(
          key: ValueKey('attempts-$_reload'),
          future: Repos.examAttempts(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(14),
                child: SkeletonRow(),
              );
            }
            final attempts = snap.data?.data ?? const <RowData>[];
            if (attempts.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(14),
                child: EmptyState(
                  title: 'Belum ada hasil ujian',
                  message: 'Hasil CBT akan tampil di sini.',
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
                final judul = (a['exams'] is Map)
                    ? ((a['exams'] as Map)['judul']?.toString() ?? '-')
                    : '-';
                final status = a['status']?.toString() ?? 'menunggu';
                final nilai = a['nilai_pilihan'];
                final maks = a['total_skor'];
                final adaNilai = nilai != null && maks is num && maks > 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      title: Text(
                        judul,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                      subtitle: Text(
                        'Percobaan ${a['percobaan'] ?? 1} · $status'
                        '${adaNilai ? ' · $nilai/$maks' : ''}',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                      trailing: nilai == null
                          ? const StatusBadge(
                              label: 'Menunggu', state: BadgeState.neutral)
                          : Text(
                              nilai.toString(),
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

  Future<void> _openExam(BuildContext context, RowData e) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _ExamDetailPage(exam: e)),
    );
    if (mounted) setState(() => _reload++);
  }
}

class _ExamDetailPage extends StatefulWidget {
  const _ExamDetailPage({required this.exam});

  final RowData exam;

  @override
  State<_ExamDetailPage> createState() => _ExamDetailPageState();
}

class _ExamDetailPageState extends State<_ExamDetailPage> {
  bool _pakaiKunci = false;

  String get _examId => widget.exam['id']?.toString() ?? '';
  String get _status => widget.exam['status']?.toString() ?? 'draft';

  bool get _bolehLihatKunci =>
      _status == 'selesai' || _status == 'dipublikasikan';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.exam['judul']?.toString() ?? 'Detail Ujian',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: FutureBuilder<QueryResult<RowData>>(
        future: _pakaiKunci
            ? Repos.examQuestionsWithKey(_examId)
            : Repos.examQuestions(_examId),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: SkeletonRow(),
            );
          }
          if (snap.data?.error != null) {
            return ErrorState(message: snap.data!.error!);
          }
          final qs = snap.data?.data ?? const <RowData>[];
          if (qs.isEmpty) {
            return const EmptyState(
              title: 'Belum ada soal',
              message: 'Soal ujian akan tampil di sini.',
              icon: Icons.list_outlined,
            );
          }
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
                        label: _status.toUpperCase(),
                        state: _status == 'aktif'
                            ? BadgeState.success
                            : BadgeState.neutral,
                      ),
                      const Spacer(),
                      if (_status == 'aktif')
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
                            label: q['tipe'] == 'esai'
                                ? 'Esai'
                                : 'Pilihan Ganda',
                            state: BadgeState.info,
                          ),
                          const Spacer(),
                          Text(
                            'Skor: ${q['skor'] ?? 0}',
                            style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary),
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
                      if (q['tipe'] != 'esai') ...[
                        const SizedBox(height: 8),
                        for (final val in ['a', 'b', 'c', 'd'])
                          if (q['opsi_$val'] != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Text('${val.toUpperCase()}. ',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13)),
                                  Expanded(
                                    child: Text(q['opsi_$val'].toString()),
                                  ),
                                ],
                              ),
                            ),
                      ],
                      if (q['kunci'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Kunci: ${q['kunci']}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.success,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: _bolehLihatKunci
          ? FloatingActionButton.extended(
              onPressed: () => setState(() => _pakaiKunci = !_pakaiKunci),
              icon: Icon(_pakaiKunci
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              label: Text(_pakaiKunci ? 'Sembunyikan kunci' : 'Lihat kunci'),
            )
          : null,
    );
  }

  /// Menjalankan ujian sungguhan. Sebelumnya method ini hanya menampilkan
  /// toast "Menjalankan ujian..." tanpa membuat attempt maupun menyimpan
  /// jawaban apa pun — tombol dekoratif yang dilarang spesifikasi.
  Future<void> _startExam(BuildContext context) async {
    if (_examId.isEmpty) {
      showToast(context, 'Ujian tidak valid.', color: AppColors.danger);
      return;
    }
    final durasi = (widget.exam['durasi_menit'] as num?)?.toInt() ?? 60;
    final hasil = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ExamTakePage(
          examId: _examId,
          judul: widget.exam['judul']?.toString() ?? 'Ujian',
          durasiMenit: durasi,
        ),
      ),
    );
    if (!context.mounted) return;
    if (hasil != null) {
      showToast(context, hasil, color: AppColors.success);
    }
  }
}
