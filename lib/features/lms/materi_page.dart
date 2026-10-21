import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/lampiran.dart';
import '../../services/repositories.dart';
import '../../widgets/app_states.dart';
import '../../widgets/common.dart';
import '../../widgets/dashboard_widgets.dart';
import 'materi_detail_page.dart';

/// Buat materi pembelajaran (guru/admin): upload file + terbitkan.
/// RLS: insert hanya admin, atau staff (guru) yang jadi pembuat.
class MateriPage extends StatefulWidget {
  const MateriPage({super.key});
  @override
  State<MateriPage> createState() => _MateriPageState();
}

class _MateriPageState extends State<MateriPage> {
  final _judul = TextEditingController();
  final _deskripsi = TextEditingController();
  final _tenggat = TextEditingController();
  bool _terbit = false;
  String? _fileUrl;
  String? _fileNama;
  List<RowData> _mapel = const [];
  List<RowData> _kelas = const [];
  String? _subjectId;
  String? _classId;
  bool _muat = true;
  bool _sibuk = false;

  @override
  void initState() {
    super.initState();
    _muatData();
    _muatDrafts();
  }

  Future<void> _muatData() async {
    final sm = await Repos.subjects();
    final kl = await Repos.classes();
    if (!mounted) return;
    setState(() {
      _mapel = sm.data;
      _kelas = kl.data;
      _muat = false;
    });
  }

  Future<void> _pickFile() async {
    final url = await Lampiran.pickAndUpload(
      allowedExtensions: const [
        'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx',
        'jpg', 'jpeg', 'png', 'mp4', 'mp3', 'm4a',
      ],
    );
    if (url != null && mounted) {
      setState(() {
        _fileUrl = url;
        _fileNama = url.split('/').last;
      });
    }
  }

  Future<void> _simpan() async {
    final uid = Repos.db.auth.currentUser?.id;
    if (_judul.text.trim().isEmpty || _subjectId == null) {
      showToast(context, 'Judul dan mapel wajib diisi.');
      return;
    }
    setState(() => _sibuk = true);
    try {
      await Repos.db.from('learning_materials').insert({
        'subject_id': _subjectId,
        'class_id': _classId,
        'dibuat_oleh': uid ?? '',
        'judul': _judul.text.trim(),
        'deskripsi':
            _deskripsi.text.trim().isEmpty ? null : _deskripsi.text.trim(),
        'file_url': _fileUrl,
        'file_nama': _fileNama,
        'tenggat': _tenggat.text.trim().isEmpty
            ? null
            : _tenggat.text.trim(),
        'dipublikasikan': _terbit,
      });
      if (!mounted) return;
      _judul.clear();
      _deskripsi.clear();
      _tenggat.clear();
      setState(() {
        _fileUrl = null;
        _fileNama = null;
        _terbit = false;
      });
      showToast(context,
          _terbit ? 'Materi diterbitkan ✓' : 'Materi disimpan sebagai draf.',
          color: AppColors.success);
    } catch (e) {
      if (!mounted) return;
      showToast(context, 'Gagal: $e', color: AppColors.danger);
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  void dispose() {
    _judul.dispose();
    _deskripsi.dispose();
    _tenggat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Terbitkan Materi')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_muat)
                      const Padding(padding: EdgeInsets.all(8), child: SkeletonRow())
                    else ...[
                      DropdownButtonFormField<String>(
                        value: _subjectId,
                        decoration: const InputDecoration(
                            labelText: 'Mata pelajaran *'),
                        items: [
                          for (final s in _mapel)
                            DropdownMenuItem(
                                value: s['id']?.toString(),
                                child: Text(s['nama']?.toString() ?? '-')),
                        ],
                        onChanged: (v) => setState(() => _subjectId = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _classId,
                        decoration:
                            const InputDecoration(labelText: 'Kelas (opsional)'),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('Semua kelas')),
                          for (final k in _kelas)
                            DropdownMenuItem(
                                value: k['id']?.toString(),
                                child: Text('Kelas ${k['nama']}')),
                        ],
                        onChanged: (v) => setState(() => _classId = v),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _judul,
                        decoration:
                            const InputDecoration(labelText: 'Judul materi *'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _deskripsi,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            labelText: 'Deskripsi (opsional)'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _tenggat,
                        decoration: const InputDecoration(
                            labelText: 'Tenggat (opsional, YYYY-MM-DD)'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _sibuk || _muat ? null : _pickFile,
                        icon: const Icon(Icons.upload_file_outlined),
                        label: Text(_fileNama != null
                            ? 'File terpasang: $_fileNama ✓'
                            : 'Unggah file materi (PDF/video) — opsional'),
                      ),
                      if (_fileNama != null)
                        TextButton(
                          onPressed: _sibuk
                              ? null
                              : () {
                                  setState(() {
                                    _fileUrl = null;
                                    _fileNama = null;
                                  });
                                },
                          child: const Text('Hapus file'),
                        ),
                      const SizedBox(height: 4),
                      SwitchListTile(
                        title: const Text('Terbitkan sekarang'),
                        subtitle: const Text(
                            'Materi langsung terlihat oleh siswa kelas terkait.'),
                        value: _terbit,
                        onChanged:
                            _sibuk ? null : (v) => setState(() => _terbit = v),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _sibuk ? null : _simpan,
                        child: _sibuk
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.4, color: Colors.white))
                            : const Text('Simpan materi'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const SectionHeader(title: 'Materi Anda (draf)'),
            const SizedBox(height: 8),
            if (_draftsDimuat)
              const Padding(
                  padding: EdgeInsets.all(8), child: SkeletonRow())
            else if (_drafts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Belum ada draf materi.',
                  style: TextStyle(
                      fontSize: 12.5, color: AppColors.textSecondary),
                ),
              )
            else
              for (final d in _drafts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      title: Text(d['judul']?.toString() ?? '-',
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        'Draf • ${d['created_at']?.toString().split('T').first}',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                      isThreeLine: false,
                      leading: const Icon(Icons.drafts_outlined,
                          color: AppColors.warning, size: 22),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 20, color: AppColors.danger),
                        onPressed: () => _hapusDraft(d),
                      ),
                      onTap: () => _terbitkan(d),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  List<RowData> _drafts = const [];
  bool _draftsDimuat = true;

  Future<void> _muatDrafts() async {
    final uid = Repos.db.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _draftsDimuat = false);
      return;
    }
    final rows = await Repos.db
        .from('learning_materials')
        .select()
        .eq('dibuat_oleh', uid)
        .eq('dipublikasikan', false)
        .order('created_at', ascending: false)
        .limit(50);
    if (!mounted) return;
    setState(() {
      _drafts = [for (final r in rows) Map<String, dynamic>.from(r as Map)];
      _draftsDimuat = false;
    });
  }

  Future<void> _hapusDraft(RowData d) async {
    if (!context.mounted) return;
    final hapus = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus materi?'),
        content: Text(
            '"${d['judul']}" akan dihapus permanen.\nFile-nya tetap di storage.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (hapus != true) return;
    final id = d['id']?.toString();
    if (id == null) return;
    try {
      await Repos.db.from('learning_materials').delete().eq('id', id);
      _muatDrafts();
      showToast(context, 'Materi dihapus.', color: AppColors.success);
    } catch (e) {
      showToast(context, 'Gagal hapus: $e', color: AppColors.danger);
    }
  }

  Future<void> _terbitkan(RowData d) async {
    final id = d['id']?.toString();
    if (id == null) return;
    try {
      await Repos.db
          .from('learning_materials')
          .update({'dipublikasikan': true})
          .eq('id', id);
      _muatDrafts();
      if (context.mounted) {
        showToast(context, '"${d['judul']}" diterbitkan ✓',
            color: AppColors.success);
      }
    } catch (e) {
      if (context.mounted) {
        showToast(context, 'Gagal terbit: $e', color: AppColors.danger);
      }
    }
  }
}
