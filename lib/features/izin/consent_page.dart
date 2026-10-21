import 'package:flutter/material.dart';

import '../../core/models/session_profile.dart';
import '../../core/theme.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';
import '../../widgets/dashboard_widgets.dart';

/// Halaman consent form:
/// - Admin: buat form + pantau respons ortu
/// - Ortu: jawab form (setuju/tidak) + catatan medik
class ConsentPage extends StatefulWidget {
  const ConsentPage({super.key, required this.profile});
  final SessionProfile profile;

  @override
  State<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends State<ConsentPage> {
  bool _muat = true;
  final _forms = <RowData>[];
  final _respons = <RowData>[];

  // Buat form (admin)
  bool _tampilBuat = false;
  String _judul = '', _desk = '', _tenggat = '';
  bool _catatMedik = false;
  bool _sibukBuat = false;
  String? _mabitId;

  @override
  void initState() {
    super.initState();
    _muat();
    if (widget.profile.isStaff || widget.profile.isAdmin) {
      _muatMabitEvents();
      _muatGuruList();
    }
  }

  Future<void> _muatMabitEvents() async {
    try {
      final events = await Repos.db
          .from('mabit_events')
          .select()
          .eq('status', 'aktif')
          .order('tanggal_mulai', ascending: false)
          .limit(50);
      if (!mounted) return;
      setState(() {
        _mabitEvents
            .addAll([for (final e in events) Map<String, dynamic>.from(e as Map)]);
      });
    } catch (_) {}
  }

  Future<void> _muatGuruList() async {
    try {
      final guru = await Repos.db
          .from('profiles')
          .select()
          .eq('role', 'guru')
          .limit(100);
      if (!mounted) return;
      setState(() {
        _guruList
            .addAll([for (final g in guru) Map<String, dynamic>.from(g as Map)]);
      });
    } catch (_) {}
  }

  final _mabitEvents = <RowData>[];
  final _guruList = <RowData>[];

  Future<void> _muat() async {
    setState(() => _muat = true);
    try {
      final isParent = widget.profile.isParent;
      final uid = Repos.uid;

      final forms = await Repos.db
          .from('consent_forms')
          .select(
              '*, mabit_events(nama_kegiatan, lokasi, tanggal_mulai, tanggal_selesai)')
          .order('created_at', ascending: false)
          .limit(100);

      List<RowData> resp = [];
      if (isParent) {
        for (final aid in widget.profile.parentStudentIds) {
          final r = await Repos.db
              .from('consent_responses')
              .select()
              .eq('parent_user_id', uid)
              .eq('student_user_id', aid);
          resp = resp + r;
        }
      } else if (widget.profile.isAdmin || widget.profile.isStaff) {
        resp = await Repos.db.from('consent_responses').select().limit(200);
      }

      if (!mounted) return;
      setState(() {
        _muat = false;
        _forms
            .addAll([for (final f in forms) Map<String, dynamic>.from(f as Map)]);
        _respons.clear();
        _respons
            .addAll([for (final r in resp) Map<String, dynamic>.from(r as Map)]);
      });
    } catch (_) {
      if (mounted) setState(() => _muat = false);
    }
  }

  Future<void> _buatForm() async {
    if (_judul.trim().isEmpty) {
      showToast(context, 'Judul wajib diisi.', color: AppColors.danger);
      return;
    }
    if (_tenggat.trim().isEmpty) {
      showToast(context, 'Tenggat wajib diisi.', color: AppColors.danger);
      return;
    }
    if (_mabitId == null) {
      showToast(context, 'Pilih kegiatan MABIT.', color: AppColors.danger);
      return;
    }
    setState(() => _sibukBuat = true);
    try {
      await Repos.db.from('consent_forms').insert({
        'event_id': _mabitId,
        'judul': _judul.trim(),
        'deskripsi': _desk.trim().isEmpty ? null : _desk.trim(),
        'tenggat': _tenggat.trim(),
        'catat_medik_aktif': _catatMedik,
      });
      if (!mounted) return;
      setState(() {
        _sibukBuat = false;
        _tampilBuat = false;
        _judul = '';
        _desk = '';
        _tenggat = '';
        _catatMedik = false;
        _mabitId = null;
      });
      showToast(context, 'Consent form dibuat ✓', color: AppColors.success);
      _muat();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sibukBuat = false);
      showToast(context, 'Gagal: $e', color: AppColors.danger);
    }
  }

  Future<void> _saveJawaban(
      RowData form, String jawaban, {String catatanMedik = ''}) async {
    final formId = form['id']?.toString() ?? '';
    final uid = Repos.uid;
    final anakIds = widget.profile.parentStudentIds;
    final studentId = anakIds.isNotEmpty ? anakIds.first : null;
    if (studentId == null) {
      showToast(context, 'Tidak ada anak terkait.', color: AppColors.danger);
      return;
    }

    try {
      final existing = await Repos.db
          .from('consent_responses')
          .select()
          .eq('form_id', formId)
          .eq('parent_user_id', uid)
          .eq('student_user_id', studentId);

      if (existing.isNotEmpty) {
        await Repos.db.from('consent_responses').update({
          'jawaban': jawaban,
          'catatan_medik': catatanMedik.isEmpty ? null : catatanMedik,
          'status': jawaban == 'setuju' ? 'disetujui' : 'ditolak',
        }).eq('id', existing.first['id']?.toString() ?? '');
      } else {
        await Repos.db.from('consent_responses').insert({
          'form_id': formId,
          'parent_user_id': uid,
          'student_user_id': studentId,
          'jawaban': jawaban,
          'catatan_medik': catatanMedik.isEmpty ? null : catatanMedik,
          'status': jawaban == 'setuju' ? 'disetujui' : 'ditolak',
        });
      }

      if (!mounted) return;
      showToast(context, 'Jawaban tersimpan ✓', color: AppColors.success);
      _muat();
    } catch (e) {
      if (!mounted) return;
      showToast(context, 'Gagal simpan: $e', color: AppColors.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isParent = widget.profile.isParent;
    final isStaff = widget.profile.isStaff || widget.profile.isAdmin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Form Persetujuan Ortu'),
        actions: [
          if (isStaff)
            IconButton(
              icon: const Icon(Icons.add_outlined),
              onPressed: () {
                setState(() {
                  _tampilBuat = !_tampilBuat;
                  _judul = '';
                  _desk = '';
                  _tenggat = '';
                  _catatMedik = false;
                  _mabitId = null;
                });
              },
            ),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _muat),
        ],
      ),
      body: Column(
        children: [
          if (isStaff && _tampilBuat) _buildFormBuat(),
          Expanded(
            child: _muat
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : isParent
                    ? _buildOrtuView()
                    : _buildAdminView(),
          ),
        ],
      ),
    );
  }

  Widget _buildFormBuat() {
    return Card(
      margin: const EdgeInsets.all(18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
                'Buat Form Persetujuan',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (_mabitEvents.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Belum ada kegiatan MABIT aktif.',
                    style: TextStyle(fontSize: 12, color: AppColors.danger)),
              ),
            if (_mabitEvents.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _mabitId,
                decoration: const InputDecoration(
                    labelText: 'Kegiatan MABIT *'),
                items: [
                  for (final e in _mabitEvents)
                    DropdownMenuItem(
                        value: e['id']?.toString(),
                        child: Text(e['nama_kegiatan']?.toString() ??
                            'Kegiatan')),
                ],
                onChanged: (v) => setState(() => _mabitId = v),
              ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => _judul = v,
              decoration: const InputDecoration(labelText: 'Judul form *'),
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => _desk = v,
              maxLines: 3,
              decoration:
                  const InputDecoration(labelText: 'Deskripsi (opsional)'),
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => _tenggat = v,
              decoration: const InputDecoration(
                  labelText: 'Tenggat (YYYY-MM-DD) *'),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('Catatan medik wajib diisi'),
              value: _catatMedik,
              onChanged: (v) => setState(() => _catatMedik = v ?? false),
            ),
            const SizedBox(height: 4),
            FilledButton(
              onPressed: _sibukBuat ? null : _buatForm,
              child: _sibukBuat
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white))
                  : const Text('Buat form'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrtuView() {
    final anakIds = widget.profile.parentStudentIds;
    if (anakIds.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
            child: Text('Tidak ada anak terkait.',
                style: TextStyle(fontSize: 13))),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(18),
      itemCount: _forms.length,
      itemBuilder: (context, i) {
        final f = _forms[i];
        final formId = f['id']?.toString() ?? '';
        final mabit = f['mabit_events'] as Map?;
        final sudahJawab = _respons
            .where((r) => r['form_id']?.toString() == formId)
            .toList();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  f['judul']?.toString() ?? 'Form Persetujuan',
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                if (mabit != null && mabit.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Kegiatan: ${mabit['nama_kegiatan'] ?? '-'} • ${mabit['lokasi'] ?? '-'} • ${mabit['tanggal_mulai']?.toString() ?? ''}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ),
                if (f['deskripsi'] != null &&
                    f['deskripsi']!.toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      f['deskripsi'].toString(),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                const SizedBox(height: 8),
                if (sudahJawab.isEmpty)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              _saveJawaban(f, 'setuju'),
                          child:
                              const Text('Setuju', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _saveJawaban(f, 'tidak_setuju'),
                          child: Text('Tidak Setuju',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.danger)),
                        ),
                      ),
                    ],
                  ),
                else
                  for (final r in sudahJawab)
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 18, color: AppColors.success),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Jawaban: ${r['jawaban'] == 'setuju' ? 'Setuju' : 'Tidak Setuju'} • ${r['created_at']?.toString().split('T').first}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdminView() {
    return ListView.builder(
      padding: const EdgeInsets.all(18),
      itemCount: _forms.length,
      itemBuilder: (context, i) {
        final f = _forms[i];
        final formId = f['id']?.toString() ?? '';
        final mabit = f['mabit_events'] as Map?;
        final resp = _respons
            .where((r) => r['form_id']?.toString() == formId)
            .toList();

        final setuju = resp.where((r) => r['jawaban'] == 'setuju').length;
        final tidak =
            resp.where((r) => r['jawaban'] == 'tidak_setuju').length;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        f['judul']?.toString() ?? 'Form',
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      'Setuju: $setuju / Tidak: $tidak',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                if (mabit != null && mabit.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Kegiatan: ${mabit['nama_kegiatan'] ?? '-'} • Tenggat: ${f['tenggat']?.toString() ?? '-'}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textSecondary),
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
