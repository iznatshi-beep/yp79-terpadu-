import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/repositories.dart';

/// Form broadcast pengumuman (admin).
class BroadcastPengumumanPage extends StatefulWidget {
  const BroadcastPengumumanPage({super.key});

  @override
  State<BroadcastPengumumanPage> createState() =>
      _BroadcastPengumumanPageState();
}

class _BroadcastPengumumanPageState extends State<BroadcastPengumumanPage> {
  final _judul = TextEditingController();
  final _isi = TextEditingController();
  String _kategori = 'umum';
  String _prioritas = 'biasa';
  bool _sibuk = false;

  @override
  void dispose() {
    _judul.dispose();
    _isi.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (_judul.text.trim().isEmpty || _isi.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Judul dan isi pengumuman wajib diisi.')));
      return;
    }
    setState(() => _sibuk = true);
    final err = await Repos.terbitkanPengumuman(
      judul: _judul.text.trim(),
      isi: _isi.text.trim(),
      kategori: _kategori,
      prioritas: _prioritas,
      target: 'semua',
    );
    if (!mounted) return;
    setState(() => _sibuk = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.danger));
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Broadcast Pengumuman')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _judul,
              decoration: const InputDecoration(labelText: 'Judul'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _isi,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Isi pengumuman'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _kategori,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: const [
                DropdownMenuItem(value: 'umum', child: Text('Umum')),
                DropdownMenuItem(value: 'akademik', child: Text('Akademik')),
                DropdownMenuItem(value: 'keuangan', child: Text('Keuangan')),
                DropdownMenuItem(value: 'kegiatan', child: Text('Kegiatan')),
                DropdownMenuItem(value: 'darurat', child: Text('Darurat')),
              ],
              onChanged: (v) => setState(() => _kategori = v ?? 'umum'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _prioritas,
              decoration: const InputDecoration(labelText: 'Prioritas'),
              items: const [
                DropdownMenuItem(value: 'biasa', child: Text('Biasa')),
                DropdownMenuItem(value: 'penting', child: Text('Penting')),
                DropdownMenuItem(value: 'darurat', child: Text('Darurat')),
              ],
              onChanged: (v) => setState(() => _prioritas = v ?? 'biasa'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _sibuk ? null : _simpan,
              child: _sibuk
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white))
                  : const Text('Terbitkan'),
            ),
          ],
        ),
      ),
    );
  }
}
