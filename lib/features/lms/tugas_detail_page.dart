import 'package:flutter/material.dart';

import '../../core/models/session_profile.dart';
import '../../core/theme.dart';
import '../../services/repositories.dart';
import '../../widgets/app_states.dart';
import '../../widgets/common.dart';
import 'nilai_submission_page.dart';

/// Halaman detail tugas: siswa mengumpulkan, guru/admin menilai.
class TugasDetailPage extends StatelessWidget {
  const TugasDetailPage({super.key, required this.profile, required this.tugas});

  final SessionProfile profile;
  final Map<String, dynamic> tugas;

  @override
  Widget build(BuildContext context) {
    final isStaff = profile.role.isStaff;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(tugas['judul']?.toString() ?? 'Tugas'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                boxShadow: appSoftShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tugas['judul']?.toString() ?? '-',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tenggat: ${tugas['tenggat']?.toString().split('T').first ?? '-'}',
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                  if ((tugas['deskripsi']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      tugas['deskripsi'].toString(),
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (isStaff)
              _DaftarUntukDinilai(assignmentId: tugas['id']?.toString() ?? '')
            else
              _FormKumpul(
                assignmentId: tugas['id']?.toString() ?? '',
                studentId: profile.studentId ?? profile.sub ?? '',
              ),
          ],
        ),
      ),
    );
  }
}

/// Siswa: isi jawaban + kumpulkan (upsert, boleh ulang sebelum dinilai).
class _FormKumpul extends StatefulWidget {
  const _FormKumpul({required this.assignmentId, required this.studentId});

  final String assignmentId;
  final String studentId;

  @override
  State<_FormKumpul> createState() => _FormKumpulState();
}

class _FormKumpulState extends State<_FormKumpul> {
  final _jawaban = TextEditingController();
  bool _sibuk = false;

  @override
  void dispose() {
    _jawaban.dispose();
    super.dispose();
  }

  Future<void> _kumpul() async {
    if (_jawaban.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tulis jawaban dulu.'),
          backgroundColor: AppColors.danger));
      return;
    }
    setState(() => _sibuk = true);
    final ok = await Repos.submitAssignment(
      assignmentId: widget.assignmentId,
      studentId: widget.studentId,
      jawaban: _jawaban.text.trim(),
    );
    if (!mounted) return;
    setState(() => _sibuk = false);
    if (ok) {
      showToast(context, 'Tugas terkumpul.',
          color: AppColors.success);
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Gagal mengumpulkan. Coba lagi.'),
          backgroundColor: AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _jawaban,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Jawaban Anda',
            hintText: 'Tulis jawaban atau rangkuman pekerjaan…',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _sibuk ? null : _kumpul,
          child: _sibuk
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: Colors.white))
              : const Text('Kumpulkan tugas'),
        ),
      ],
    );
  }
}

/// Guru/admin: daftar pengumpulan untuk satu tugas + beri nilai.
class _DaftarUntukDinilai extends StatelessWidget {
  const _DaftarUntukDinilai({required this.assignmentId});

  final String assignmentId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QueryResult<Map<String, dynamic>>>(
      future: Repos.submissions(assignmentId: assignmentId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(16), child: SkeletonRow());
        }
        final subs = snap.data?.data ?? const [];
        if (subs.isEmpty) {
          return const EmptyState(
            title: 'Belum ada pengumpulan',
            message: 'Jawaban siswa akan tampil di sini.',
            icon: Icons.inbox_outlined,
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: subs.length,
          itemBuilder: (context, i) {
            final s = subs[i];
            final sudahDinilai = s['nilai'] != null;
            return Card(
              child: ListTile(
                title: Text('Siswa: ${s['student_user_id']?.toString() ?? '-'}',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                    'Status: ${s['status'] ?? '-'} · Nilai: ${s['nilai'] ?? '-'}'),
                trailing: Icon(sudahDinilai
                    ? Icons.check_circle_outline
                    : Icons.edit_outlined),
                onTap: () async {
                  final ok = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NilaiSubmissionPage(submission: s),
                    ),
                  );
                  if (ok == true && context.mounted) {
                    Navigator.pop(context, true); // kembali ke LMS & refresh
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}
