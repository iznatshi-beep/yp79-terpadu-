import 'package:flutter/material.dart';

import '../../core/models/session_profile.dart';
import '../../core/theme.dart';
import '../../services/repositories.dart';
import '../../widgets/app_states.dart';
import '../../widgets/common.dart';

/// Rapor siswa: admin buat per siswa (nilai akhir + predikat + catatan),
/// bisa draft / publish. Ortu/siswa melihat rapor yang sudah dipublikasikan.
class RaporPage extends StatefulWidget {
  const RaporPage({super.key, required this.profile});

  final SessionProfile profile;

  @override
  State<RaporPage> createState() => _RaporPageState();
}

class _RaporPageState extends State<RaporPage> {
  bool _dimuat = false;
  bool _menunggu = false;
  String? _error;

  List<RowData> _raports = [];
  List<RowData> _items = [];
  String? _raportDipilih;

  // Form create
  bool _tampilBuat = false;
  bool _sibukBuat = false;
  List<RowData> _siswa = [];
  List<RowData> _mapel = [];
  String? _siswaPilih;
  String _semester = 'gasal';
  String _tahun = '2026/2027';
  String _catatanKarakter = '';
  bool _publikasikan = true;
  final Map<String, double> _nilai = {}; // subject_id -> nilai
  final Map<String, String> _predikat = {};
  final Map<String, String> _catatanMapel = {};

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _dimuat = false;
      _error = null;
    });
    final results = await Future.wait([
      Repos.raports(),
      Repos.listSiswa(),
      Repos.subjects(),
    ]);
    final r = results[0];
    final s = results[1];
    final m = results[2];
    if (!mounted) return;
    if (r.error != null) {
      setState(() {
        _error = r.error;
        _dimuat = true;
      });
      return;
    }
    setState(() {
      _raports = r.data;
      _siswa = s.data;
      _mapel = m.data;
      _dimuat = true;
    });
  }

  Future<void> _muatItems(String raportId) async {
    setState(() => _menunggu = true);
    final res = await Repos.raportItems(raportId);
    if (!mounted) return;
    setState(() {
      _items = res.data;
      _menunggu = false;
      _raportDipilih = raportId;
    });
  }

  // ---- predikat dari angka ----
  String _hitungPredikat(double nilai) {
    if (nilai >= 90) return 'A';
    if (nilai >= 80) return 'B';
    if (nilai >= 70) return 'C';
    if (nilai >= 60) return 'D';
    return 'E';
  }

  Future<void> _buat() async {
    if (_siswaPilih == null) {
      showToast(context, 'Pilih siswa.', color: AppColors.danger);
      return;
    }
    if (_mapel.isEmpty) {
      showToast(context, 'Tidak ada mapel di sistem.',
          color: AppColors.danger);
      return;
    }
    final items = <RowData>[];
    for (final m in _mapel) {
      final sid = m['id']?.toString();
      if (sid == null) continue;
      final nilai = _nilai[sid] ?? 0.0;
      items.add({
        'subject_id': sid,
        'nilai_akhir': nilai,
        'predikat': _hitungPredikat(nilai),
        'catatan_guru': _catatanMapel[sid],
      });
    }
    setState(() => _sibukBuat = true);
    final err = await Repos.buatRaport(
      studentId: _siswaPilih!,
      semester: _semester,
      tahunAjaran: _tahun,
      items: items,
      catatanKarakter: _catatanKarakter,
      publikasikan: _publikasikan,
    );
    if (!mounted) return;
    setState(() {
      _sibukBuat = false;
      _tampilBuat = false;
    });
    if (err == null) {
      showToast(context, _publikasikan
          ? 'Rapor dipublikasikan.'
          : 'Rapor disimpan sebagai draf.');
      await _muat();
    } else {
      showToast(context, err, color: AppColors.danger);
    }
  }

  Future<void> _terbitkan(String id) async {
    final err = await Repos.ubahStatusRaport(id, 'dipublikasikan');
    if (!mounted) return;
    if (err == null) {
      showToast(context, 'Rapor dipublikasikan.');
      await _muat();
    } else {
      showToast(context, err, color: AppColors.danger);
    }
  }

  Future<void> _hapus(String id) async {
    final ok = await showConfirmDialog(
      context,
      judul: 'Hapus Rapor',
      pesan: 'Rapor beserta nilai mapelnya akan dihapus permanen.',
      tombolYa: 'Hapus',
      warnColor: AppColors.danger,
    );
    if (!ok) return;
    final err = await Repos.hapusRaport(id);
    if (!mounted) return;
    if (err == null) {
      showToast(context, 'Rapor dihapus.');
      await _muat();
    } else {
      showToast(context, err, color: AppColors.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = widget.profile.isAdmin;
    final ortu = widget.profile.isParent;

    if (!_dimuat) {
      return AppStates.loading(rows: 5);
    }
    if (_error != null) {
      return AppStates.error(message: _error!, onRetry: _muat);
    }

    // Ortu / siswa: tampilkan daftar rapor ANAK MEREKA (yang published).
    final daftar = ortu
        ? _raports.where((r) {
            final sid = r['student_user_id']?.toString();
            return widget.profile.parentStudentIds.contains(sid);
          }).toList()
        : _raports;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Rapor'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (admin)
            IconButton(
              onPressed: () => setState(() => _tampilBuat = true),
              icon: const Icon(Icons.add_a_card_outlined),
            ),
          IconButton(
            onPressed: _muat,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _tampilBuat && admin
          ? _buildFormBuat()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (admin && daftar.isEmpty)
                  AppStates.empty(
                    judul: 'Belum ada rapor',
                    pesan:
                        'Buat rapor dengan tombol + di kanan atas, atau mulai dari data nilai yang sudah diinput.',
                    action: ElevatedButton(
                      onPressed: () => setState(() => _tampilBuat = true),
                      child: const Text('Buat Rapor'),
                    ),
                  )
                else
                  ...daftar.map((r) => _buildRaportCard(r)),
              ],
            ),
    );
  }

  Widget _buildRaportCard(RowData r) {
    final id = r['id']?.toString() ?? '';
    final sp = (r['student_profiles'] as Map?) ?? const {};
    final nama = sp['nama_lengkap']?.toString() ?? 'Siswa';
    final nis = sp['nis']?.toString() ?? '';
    final status = r['status']?.toString() ?? 'draf';
    final semester = r['semester']?.toString() ?? '';
    final tahun = r['tahun_ajaran']?.toString() ?? '';
    final catatan = r['catatan_karakter']?.toString();
    final dipub = r['dipublikasikan_pada'];
    final terpilih = _raportDipilih == id;

    final badge = status == 'dipublikasikan'
        ? _Badge(
            teks: 'Dipublikasikan',
            bg: AppColors.successBg,
            teks: AppColors.success,
          )
        : _Badge(teks: 'Draf', bg: AppColors.warningBg, teks: AppColors.warning);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: terpilih ? AppColors.primary : AppColors.line,
          width: terpilih ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    nama,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                badge,
              ],
            ),
            if (nis.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('NIS $nis  •  $semester  •  $tahun',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.muted)),
              ),
            if (catatan != null && catatan.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Catatan karakter: $catatan',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            if (dipub != null)
              Text(
                'Dipublikasikan: ${_formatTanggal(dipub.toString())}',
                style:
                    const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _muatItems(id),
                    icon: const Icon(Icons.subject, size: 16),
                    label: const Text(terpilih ? 'Tutup nilai' : 'Lihat nilai'),
                    style: OutlinedButtonStyle(
                      side: const BorderSide(color: AppColors.primary),
                      foregroundColor: const MaterialStatePropertyAll(
                          AppColors.primary),
                    ),
                  ),
                ),
                if (widget.profile.isAdmin) ...[
                  if (status != 'dipublikasikan')
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => _terbitkan(id),
                        icon: const Icon(Icons.publish, size: 16),
                        label: const Text('Publish'),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: TextButton.icon(
                      onPressed: () => _hapus(id),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Hapus'),
                      style: TextButtonStyle(
                        foregroundColor:
                            const MaterialStatePropertyAll(AppColors.danger),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (terpilih) ...[
              const Divider(height: 18),
              if (_menunggu)
                const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()))
              else if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                    child: Text('Belum ada nilai mapel di rapor ini.',
                        style: TextStyle(color: AppColors.muted)),
                  ),
                )
              else
                ..._items.map((it) {
                  final m = (it['subjects'] as Map?) ?? const {};
                  final n = it['nilai_akhir']?.toString() ?? '—';
                  final p = it['predikat']?.toString() ?? '';
                  final c = it['catatan_guru']?.toString();
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m['nama']?.toString() ?? 'Mapel',
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600)),
                              if (c != null && c.isNotEmpty)
                                Text(c,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.muted)),
                            ],
                          ),
                        ),
                        Text('$n',
                            style:
                                const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        SizedBox(
                          width: 28,
                          child: Text(
                            p,
                            textAlign: TextAlign.end,
                            style:
                                const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormBuat() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _tampilBuat = false),
              icon: const Icon(Icons.arrow_back),
            ),
            const Expanded(
                child:
                    Text('Buat Rapor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          ],
        ),
        Card(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: const BorderSide(color: AppColors.line),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: _siswaPilih,
                  decoration:
                      const InputDecoration(labelText: 'Siswa *'),
                  items: _siswa
                      .map((s) =>
                          DropdownMenuItem(
                        value: s['id']?.toString(),
                        child: Text('${s['nama'] ?? ''} (${s['nis'] ?? '—'})'),
                      ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _siswaPilih = v),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _semester,
                        decoration:
                            const InputDecoration(labelText: 'Semester'),
                        items: const [
                          DropdownMenuItem(
                              value: 'gasal', child: Text('Gasal')),
                          DropdownMenuItem(
                              value: 'genap', child: Text('Genap')),
                        ],
                        onChanged: (v) => setState(
                            () => _semester = v ?? 'gasal'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        initialValue: _tahun,
                        decoration:
                            const InputDecoration(labelText: 'Tahun Ajaran'),
                        onChanged: (v) => _tahun = v,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: _catatanKarakter,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Catatan Karakter'),
                  onChanged: (v) => _catatanKarakter = v,
                ),
                const SizedBox(height: 12),
                const Text('Nilai Akhir per Mapel',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ..._mapel.map((m) {
                  final sid = m['id']?.toString() ?? '';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(m['nama']?.toString() ?? 'Mapel',
                              style:
                                  const TextStyle(fontSize: 13.5)),
                        ),
                        SizedBox(
                          width: 64,
                          child: TextFormField(
                            initialValue:
                                _nilai[sid]?.toString(),
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: const InputDecoration(
                                isDense: true,
                                labelText: '0-100',
                                border: OutlineInputBorder()),
                            onChanged: (v) {
                              setState(() {
                                _nilai[sid] = double.tryParse(v) ?? 0.0;
                                _predikat[sid] =
                                    _hitungPredikat(_nilai[sid] ?? 0);
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 34,
                          child: Center(
                            child: Text(
                              _predikat[sid] ?? _hitungPredikat(0),
                              style:
                                  const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Publikasikan langsung',
                      style: TextStyle(fontSize: 13.5)),
                  value: _publikasikan,
                  controlAffinity:
                      MaterialControlAffinity.leading,
                  onChanged: (v) =>
                      setState(() => _publikasikan = v ?? false),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _sibukBuat ? null : _buat,
                    child: _sibukBuat
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Simpan Rapor',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatTanggal(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

class _Badge extends StatelessWidget {
  const _Badge(
      {required this.teks, required this.bg, required this.teksWarna});

  final String teks;
  final Color bg;
  final Color teksWarna;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        teks,
        style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: teksWarna),
      ),
    );
  }
}
