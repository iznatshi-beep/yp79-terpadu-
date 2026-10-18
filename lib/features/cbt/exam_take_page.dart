import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../services/repositories.dart';
import '../../../widgets/app_states.dart';
import '../../../widgets/common.dart';

/// Halaman pengerjaan ujian CBT.
///
/// Sebelumnya tombol "Mulai Ujian" hanya menampilkan toast
/// ("Menjalankan ujian...") dan tidak melakukan apa pun: tidak ada attempt
/// yang dibuat, tidak ada jawaban yang disimpan, tidak ada submit.
/// Halaman ini mengerjakan alur nyata:
///   1. `startExam` membuat baris `exam_attempts` (dibatasi RLS).
///   2. Soal diambil lewat RPC `exam_questions_public` TANPA kunci jawaban.
///   3. Setiap perubahan jawaban disimpan ke `exam_answers` (autosave).
///   4. Tombol Kirim memanggil `submitExam` lalu `finalize_cbt` di server.
class ExamTakePage extends StatefulWidget {
  const ExamTakePage({
    super.key,
    required this.examId,
    required this.judul,
    required this.durasiMenit,
  });

  final String examId;
  final String judul;
  final int durasiMenit;

  @override
  State<ExamTakePage> createState() => _ExamTakePageState();
}

class _ExamTakePageState extends State<ExamTakePage> {
  bool _loading = true;
  String? _error;
  String? _attemptId;
  List<Map<String, dynamic>> _questions = const [];
  final Map<String, String> _jawaban = {};
  final Set<String> _tersimpan = {};
  Timer? _timer;
  int _sisaDetik = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _mulai();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _mulai() async {
    final res = await Repos.startExam(
      examId: widget.examId,
      studentId: Repos.uid,
    );
    if (!mounted) return;
    if (!res.ok) {
      setState(() {
        _loading = false;
        _error = res.error ?? 'Ujian tidak dapat dimulai.';
      });
      return;
    }

    final q = await Repos.examQuestions(widget.examId);
    if (!mounted) return;
    setState(() {
      _attemptId = res.attemptId;
      _questions = q.data;
      _error = q.ok
          ? (q.data.isEmpty ? 'Ujian ini belum memiliki soal.' : null)
          : q.error;
      _loading = false;
      _sisaDetik = widget.durasiMenit * 60;
    });
    if (q.data.isNotEmpty) _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_sisaDetik <= 1) {
        t.cancel();
        setState(() => _sisaDetik = 0);
        _submit(otomatis: true);
        return;
      }
      setState(() => _sisaDetik--);
    });
  }

  String get _sisaLabel {
    final m = (_sisaDetik ~/ 60).toString().padLeft(2, '0');
    final s = (_sisaDetik % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _pilih(String questionId, String jawaban) async {
    setState(() => _jawaban[questionId] = jawaban);
    final ok = await Repos.saveExamAnswer(
      attemptId: _attemptId!,
      questionId: questionId,
      jawaban: jawaban,
    );
    if (!mounted) return;
    setState(() {
      if (ok) {
        _tersimpan.add(questionId);
      } else {
        _tersimpan.remove(questionId);
      }
    });
  }

  Future<void> _submit({bool otomatis = false}) async {
    if (_submitting || _attemptId == null) return;

    if (!otomatis) {
      final ok = await showConfirmDialog(
        context,
        judul: 'Kirim jawaban?',
        pesan:
            'Anda telah menjawab ${_jawaban.length} dari ${_questions.length} soal. '
            'Setelah dikirim, jawaban tidak dapat diubah lagi.',
        tombolYa: 'Kirim',
      );
      if (!ok) return;
    }

    setState(() => _submitting = true);
    _timer?.cancel();

    final err = await Repos.submitExam(attemptId: _attemptId!);
    if (!mounted) return;
    if (err != null) {
      setState(() => _submitting = false);
      showToast(context, 'Gagal mengirim jawaban: $err', color: AppColors.danger);
      _startTimer();
      return;
    }

    final nilai = await Repos.finalizeExam(_attemptId!);
    if (!mounted) return;
    Navigator.of(context).pop(
      otomatis
          ? 'Waktu habis — jawaban dikirim otomatis. Nilai pilihan ganda: '
              '${nilai?.toStringAsFixed(2) ?? '-'}'
          : 'Jawaban terkirim. Nilai pilihan ganda: '
              '${nilai?.toStringAsFixed(2) ?? 'menunggu koreksi'}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.judul, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (!_loading && _error == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: StatusBadge(
                  label: _sisaLabel,
                  state: _sisaDetik < 60
                      ? BadgeState.danger
                      : BadgeState.info,
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _loading || _error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Terjawab ${_jawaban.length}/${_questions.length}',
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _submitting ? null : () => _submit(),
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Kirim Jawaban'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [SkeletonRow(), SkeletonRow(), SkeletonRow()],
        ),
      );
    }
    if (_error != null) {
      return ErrorState(
        message: _error!,
        onRetry: () {
          setState(() {
            _loading = true;
            _error = null;
          });
          _mulai();
        },
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _questions.length,
      itemBuilder: (context, i) {
        final q = _questions[i];
        final qid = q['id']?.toString() ?? '';
        final tipe = q['tipe']?.toString() ?? 'pilihan';
        final terpilih = _jawaban[qid];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusBadge(
                      label: tipe == 'esai' ? 'Esai' : 'Pilihan Ganda',
                      state: BadgeState.neutral,
                    ),
                    const Spacer(),
                    Text(
                      'Soal ${i + 1} · ${q['skor'] ?? 0} poin',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                    if (_tersimpan.contains(qid)) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.cloud_done_outlined,
                          size: 15, color: AppColors.success),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  q['pertanyaan']?.toString() ?? '',
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                if (tipe == 'esai')
                  TextField(
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: 'Tulis jawaban Anda di sini...',
                    ),
                    onChanged: (v) => _pilih(qid, v),
                  )
                else
                  // RadioGroup menggantikan groupValue/onChanged pada RadioListTile
                  // yang sudah deprecated sejak Flutter 3.32.
                  RadioGroup<String>(
                    groupValue: terpilih,
                    onChanged: (v) => _pilih(qid, v ?? ''),
                    child: Column(
                      children: [
                        for (final opsi in ['A', 'B', 'C', 'D'])
                          if (q['opsi_${opsi.toLowerCase()}'] != null)
                            RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              value: opsi,
                              title: Text(
                                '$opsi. ${q['opsi_${opsi.toLowerCase()}']}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
