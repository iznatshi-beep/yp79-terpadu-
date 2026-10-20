import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/repositories.dart';
import '../../widgets/app_states.dart';
import '../../widgets/common.dart';

/// Halaman guru/admin: menilai satu pengumpulan tugas.
class NilaiSubmissionPage extends StatefulWidget {
  const NilaiSubmissionPage({super.key, required this.submission});

  final Map<String, dynamic> submission;

  @override
  State<NilaiSubmissionPage> createState() => _NilaiSubmissionPageState();
}

class _NilaiSubmissionPageState extends State<NilaiSubmissionPage> {
  late final TextEditingController _nilaiCtrl;
  late final TextEditingController _umpanCtrl;
  bool _sibuk = false;

  @override
  void initState() {
    super.initState();
    _nilaiCtrl = TextEditingController(
        text: widget.submission['nilai']?.toString() ?? '');
    _umpanCtrl = TextEditingController(
        text: widget.submission['umpan_balik']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nilaiCtrl.dispose();
    _umpanCtrl.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final n = double.tryParse(_nilaiCtrl.text.replaceAll(',', '.'));
    if (n == null || n < 0 || n > 100) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nilai harus angka 0-100.'),
          backgroundColor: AppColors.danger));
      return;
    }
    setState(() => _sibuk = true);
    final ok = await Repos.gradeSubmission(
      id: widget.submission['id'].toString(),
      nilai: n,
      umpanBalik:
          _umpanCtrl.text.trim().isEmpty ? null : _umpanCtrl.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      showToast(context, 'Nilai tersimpan.', color: AppColors.success);
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Gagal menyimpan nilai.'),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Nilai Pengumpulan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                boxShadow: appSoftShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Jawaban siswa',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Text(
                    widget.submission['jawaban_text']?.toString() ??
                        '(tanpa jawaban teks)',
                    style:
                        const TextStyle(fontSize: 13.5, color: AppColors.ink),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nilaiCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Nilai (0-100)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _umpanCtrl,
              maxLines: 3,
              decoration:
                  const InputDecoration(labelText: 'Umpan balik (opsional)'),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _sibuk ? null : _simpan,
              child: _sibuk
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Simpan nilai'),
            ),
          ],
        ),
      ),
    );
  }
}
