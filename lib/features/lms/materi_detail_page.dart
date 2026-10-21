import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../widgets/app_states.dart';
import '../../widgets/common.dart';

/// Detail satu materi LMS: info + tombol buka file (URL publik).
class MateriDetailPage extends StatelessWidget {
  const MateriDetailPage({super.key, required this.material});

  final Map<String, dynamic> material;

  Future<void> _buka(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        showToast(context, 'Tidak bisa membuka file ini.',
            color: AppColors.danger);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = material['file_url']?.toString() ?? '';
    final judul = material['judul']?.toString() ?? 'Materi';
    final subjek =
        material['subjects'] is Map ? material['subjects'] : const {};
    final kelas =
        material['classes'] is Map ? material['classes'] : const {};
    final desk = material['deskripsi']?.toString() ?? '';
    final tenggat = material['tenggat']?.toString() ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(judul)),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    judul,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  if (subjek.isNotEmpty)
                    _baris('Mapel', subjek['nama']?.toString() ?? '-'),
                  if (kelas.isNotEmpty)
                    _baris('Kelas', 'Kelas ${kelas['nama']}'),
                  if (tenggat.isNotEmpty)
                    _baris('Tenggat', tenggat.split('T').first),
                  if (desk.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(desk,
                        style: const TextStyle(fontSize: 13, height: 1.45)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (url.isNotEmpty)
            FilledButton.icon(
              onPressed: () => _buka(context, url),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Buka / Unduh materi'),
            )
          else
            const EmptyState(
              title: 'Belum ada file',
              message: 'Materi ini belum memiliki file.',
              icon: Icons.insert_drive_file_outlined,
            ),
        ],
      ),
    );
  }

  Widget _baris(String label, String nilai) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 70,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary))),
          Expanded(
              child: Text(nilai,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textPrimary))),
        ],
      ),
    );
  }
}
