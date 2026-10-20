import 'package:flutter/material.dart';

import '../../core/models/session_profile.dart';
import '../../core/theme.dart';
import '../../services/lampiran.dart';
import '../../services/repositories.dart';
import '../../widgets/app_states.dart';
import '../../widgets/common.dart';

/// Isi jurnal mutaba'ah harian (siswa): checklist ibadah + kirim.
/// Upsert per tanggal — satu baris per hari per siswa (RLS: milik sendiri).
class MutabaahFormPage extends StatefulWidget {
  const MutabaahFormPage({super.key, required this.profile});

  final SessionProfile profile;

  /// Item checklist default; bisa ditambah bebas.
  static const _itemsDefault = <String>[
    'Shalat 5 waktu tepat waktu',
    'Shalat Subuh berjamaah',
    'Dzikir pagi',
    'Dzikir petang',
    'Baca Al-Quran (1 halaman)',
    'Shalat Dhuha',
    'Shalat Witir',
    'Sedekah',
  ];

  @override
  State<MutabaahFormPage> createState() => _MutabaahFormPageState();
}

class _MutabaahFormPageState extends State<MutabaahFormPage> {
  late final Map<String, bool> _ceklis;
  bool _sibuk = false;

  @override
  void initState() {
    super.initState();
    _ceklis = {
      for (final i in MutabaahFormPage._itemsDefault) i: false,
    };
  }

  String? _lampiranUrl;

  Future<void> _simpan() async {
    setState(() => _sibuk = true);
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      // Upsert: kalau sudah ada baris hari ini, timpa checklist-nya.
      // Lampiran (foto/PDF) disimpan ke kolom `lampiran_url`.
      await Repos.db.from('mutabaah_entries').upsert({
        'student_user_id': widget.profile.studentId ?? widget.profile.sub ?? '',
        'tanggal': today,
        'checklist': _ceklis,
        'diverifikasi': false,
        if (_lampiranUrl != null) 'lampiran_url': _lampiranUrl,
      }, onConflict: 'student_user_id,tanggal');
      if (!mounted) return;
      showToast(context, 'Mutabaah hari ini tersimpan.',
          color: AppColors.success);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showToast(context, 'Gagal menyimpan: $e', color: AppColors.danger);
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _pickLampiran() async {
    final url = await Lampiran.pickAndUpload(
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (url != null && mounted) {
      setState(() => _lampiranUrl = url);
      showToast(context, 'Lampiran terpasang ✓', color: AppColors.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final terisi = _ceklis.values.where((v) => v).length;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Isi Mutaba'ah — ${_tanggalHariIni()}"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Tercentang: $terisi dari ${_ceklis.length}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
                Text(
                  '${(_ceklis.isEmpty ? 0 : terisi * 100 ~/ _ceklis.length)}%',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              children: [
                for (final entry in _ceklis.entries)
                  CheckboxListTile(
                    value: entry.value,
                    onChanged: (v) =>
                        setState(() => _ceklis[entry.key] = v ?? false),
                    title: Text(entry.key,
                        style: const TextStyle(
                            fontSize: 13.5, color: AppColors.ink)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _sibuk ? null : _pickLampiran,
                  icon: const Icon(Icons.attach_file_rounded),
                  label: Text(_lampiranUrl != null
                      ? 'Lampiran terpasang ✓'
                      : 'Lampirkan (foto/PDF) — opsional'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _sibuk ? null : _simpan,
                  child: _sibuk
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white))
                      : const Text('Simpan jurnal hari ini'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _tanggalHariIni() {
    final d = DateTime.now();
    return '${d.day}/${d.month}/${d.year}';
  }
}

/// Setor hafalan (siswa): pilih target + capaian, kirim untuk verifikasi guru.
class SetorHafalanPage extends StatefulWidget {
  const SetorHafalanPage({super.key, required this.profile});

  final SessionProfile profile;

  @override
  State<SetorHafalanPage> createState() => _SetorHafalanPageState();
}

class _SetorHafalanPageState extends State<SetorHafalanPage> {
  final _capaian = TextEditingController();
  final _catatan = TextEditingController();
  bool _sibuk = false;
  String? _lampiranUrl;

  @override
  void dispose() {
    _capaian.dispose();
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _kirim() async {
    if (_capaian.text.trim().isEmpty) {
      showToast(context, 'Isi capaian dulu (mis. "Al-Baqarah 1-10").');
      return;
    }
    setState(() => _sibuk = true);
    try {
      await Repos.db.from('memorization_submissions').insert({
        'student_user_id':
            widget.profile.studentId ?? widget.profile.sub ?? '',
        'capaian': _capaian.text.trim(),
        'catatan':
            _catatan.text.trim().isEmpty ? null : _catatan.text.trim(),
        'status': 'menunggu',
        if (_lampiranUrl != null) 'lampiran_url': _lampiranUrl,
      });
      if (!mounted) return;
      showToast(context, 'Setoran dikirim. Menunggu verifikasi guru.',
          color: AppColors.success);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showToast(context, 'Gagal mengirim: $e', color: AppColors.danger);
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _pickLampiran() async {
    final url = await Lampiran.pickAndUpload(
      allowedExtensions: const ['mp3', 'm4a', 'wav', 'mp4', 'mov', '3gp'],
    );
    if (url != null && mounted) {
      setState(() => _lampiranUrl = url);
      showToast(context, 'Audio/video terpasang ✓', color: AppColors.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Setor Hafalan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _capaian,
              decoration: const InputDecoration(
                labelText: 'Capaian hafalan',
                hintText: 'Contoh: Juz Amma An-Naba sampai An-Nazi\'at',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _catatan,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                hintText: 'Kesulitan, bimbingan yang dibutuhkan, dll.',
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _sibuk ? null : _pickLampiran,
              icon: const Icon(Icons.attach_file_rounded),
              label: Text(_lampiranUrl != null
                  ? 'Audio/video terpasang ✓'
                  : 'Lampirkan audio/video (opsional)'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _sibuk ? null : _kirim,
              child: _sibuk
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white))
                  : const Text('Kirim setoran'),
            ),
          ],
        ),
      ),
    );
  }
}
