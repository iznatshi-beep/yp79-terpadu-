import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/session_profile.dart';
import '../../core/theme.dart';
import '../../services/lampiran.dart';
import '../../services/repositories.dart';
import '../../widgets/app_states.dart';
import '../../widgets/common.dart';

/// Pelaporan kejadian (insiden) di lingkungan sekolah.
/// - Siswa / Ortu / Admin: buat laporan (bully, kecelakaan, kenakalan, dll).
/// - Admin: pantau semua laporan, ubah status (processed/resolved) + catatan,
///   hapus laporan.
class IncidentPage extends StatefulWidget {
  const IncidentPage({super.key, required this.profile});

  final SessionProfile profile;

  @override
  State<IncidentPage> createState() => _IncidentPageState();
}

class _IncidentPageState extends State<IncidentPage> {
  static const List<String> kKategori = [
    'Bullying',
    'Kecelakaan / Cedera',
    'Kenakalan / Pelanggaran',
    'Lingkungan / Keamanan',
    'Kesehatan / Medis',
    'Lainnya',
  ];

  bool _dimuat = false;
  bool _sibuk = false;
  String? _error;

  List<RowData> _laporan = [];
  Map<String, RowData> _siswaMap = {}; // user_id -> profil siswa

  // Form buat laporan
  bool _tampilBuat = false;
  String _kategoriPilih = kKategori.first;
  String _desk = '';
  String _lokasi = '';
  String? _waktuKejadian;
  String? _targetSiswaId;
  String? _lampiranUrl;

  // Detail admin
  String? _detailId;
  String _keterangan = '';

  @override
  void initState() {
    super.initState();
    _mulai();
  }

  Future<void> _mulai() async {
    setState(() {
      _dimuat = false;
      _error = null;
    });
    final results = await Future.wait([
      Repos.incidents(),
      Repos.listSiswa(),
    ]);
    final inc = results[0];
    final sis = results[1];
    if (!mounted) return;

    if (inc.error != null) {
      setState(() {
        _error = inc.error;
        _dimuat = true;
      });
      return;
    }
    final map = <String, RowData>{};
    for (final s in sis.data) {
      final id = s['id']?.toString();
      if (id != null) map[id] = s;
    }
    setState(() {
      _laporan = _filterUntukSesi(inc.data);
      _siswaMap = map;
      _dimuat = true;
    });
  }

  /// Siswa/ortu hanya lihat laporan yang mereka buat (reporter) atau yang
  /// menyangkut anak mereka (target). Admin/Guru lihat semua.
  List<RowData> _filterUntukSesi(List<RowData> all) {
    if (widget.profile.isAdmin || widget.profile.isStaff) return all;
    final uid = Repos.uid;
    final anakIds = widget.profile.parentStudentIds;
    return all.where((r) {
      final reporter = r['reporter_id']?.toString();
      final target = r['target_siswa_id']?.toString();
      final sayaBikin = reporter == uid;
      final menyangkutAnak =
          target != null && (anakIds.contains(target) || target == uid);
      return sayaBikin || menyangkutAnak;
    }).toList();
  }

  Future<void> _buat() async {
    if (_desk.trim().isEmpty) {
      showToast(context, 'Deskripsi kejadian wajib diisi.',
          color: AppColors.danger);
      return;
    }
    setState(() => _sibuk = true);
    final err = await Repos.buatInsiden(
      kategori: _kategoriPilih,
      deskripsi: _desk.trim(),
      lokasi: _lokasi.trim().isNotEmpty ? _lokasi.trim() : null,
      waktuKejadian: _waktuKejadian,
      targetSiswaId: _targetSiswaId,
      lampiranUrl: _lampiranUrl,
    );
    if (!mounted) return;
    setState(() => _sibuk = false);
    if (err != null) {
      showToast(context, 'Gagal laporkan: $err', color: AppColors.danger);
      return;
    }
    setState(() {
      _tampilBuat = false;
      _desk = '';
      _lokasi = '';
      _waktuKejadian = null;
      _targetSiswaId = null;
      _lampiranUrl = null;
      _kategoriPilih = kKategori.first;
    });
    showToast(context, 'Laporan terkirim ✓', color: AppColors.success);
    _mulai();
  }

  Future<void> _ubahStatus(String status, {bool tampilkanKeterangan = false}) async {
    if (_detailId == null) return;
    if (tampilkanKeterangan && _keterangan.trim().isEmpty) {
      showToast(context, 'Keterangan wajib diisi.', color: AppColors.danger);
      return;
    }
    final err = await Repos.updateStatusInsiden(
      _detailId!,
      status: status,
      keterangan: tampilkanKeterangan ? _keterangan.trim() : null,
    );
    if (!mounted) return;
    if (err != null) {
      showToast(context, 'Gagal: $err', color: AppColors.danger);
      return;
    }
    showToast(context, 'Status diperbarui ✓', color: AppColors.success);
    setState(() {
      _detailId = null;
      _keterangan = '';
    });
    _mulai();
  }

  Future<void> _hapus(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus laporan ini?'),
        content: const Text(
            'Tindakan ini permanen dan tidak bisa dibatalkan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    final err = await Repos.hapusInsiden(id);
    if (!mounted) return;
    if (err != null) {
      showToast(context, 'Gagal hapus: $err', color: AppColors.danger);
      return;
    }
    showToast(context, 'Laporan dihapus ✓', color: AppColors.success);
    _mulai();
  }

  Future<void> _uploadLampiran() async {
    try {
      final url = await Lampiran.pickAndUpload();
      if (!mounted) return;
      if (url != null) setState(() => _lampiranUrl = url);
    } catch (e) {
      if (mounted) {
        showToast(context, 'Gagal upload: $e', color: AppColors.danger);
      }
    }
  }

  Future<void> _bukaLampiran(String url) async {
    try {
      final uri = Uri.parse(url);
      final res = await launchUrl(uri,
          mode: LaunchMode.externalApplication);
      if (!res) {
        if (mounted) {
          showToast(context, 'Tidak bisa membuka file.',
              color: AppColors.danger);
        }
      }
    } catch (_) {}
  }

  String _namaSiswa(RowData r) {
    final tid = r['target_siswa_id']?.toString();
    final target = r['target'] as Map?;
    if (tid != null && _siswaMap.containsKey(tid)) {
      final s = _siswaMap[tid]!;
      final kelas = s['kelas_id']?.toString() ?? '';
      final nis = s['nama']?.toString() ?? '';
      return nis.isEmpty ? '-' : '$nis ($kelas)';
    }
    if (target != null && target.isNotEmpty) {
      return target['nama']?.toString() ??
          target['email']?.toString() ??
          '-';
    }
    return '-';
  }

  String _namaReporter(RowData r) {
    final rep = r['reporter'] as Map?;
    if (rep != null && rep.isNotEmpty) {
      final n = rep['nama']?.toString() ?? '';
      if (n.isNotEmpty) return n;
      return rep['email']?.toString() ?? '-';
    }
    return '-';
  }

  String _tampilkanStatus(String s) {
    switch (s) {
      case 'processed':
        return 'Ditindaklanjuti';
      case 'resolved':
        return 'Selesai';
      default:
        return 'Menunggu';
    }
  }

  Color _warnaStatus(String s) {
    switch (s) {
      case 'resolved':
        return AppColors.success;
      case 'processed':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bisaBuat = !widget.profile.isAdmin; // siswa/ortu/guru bikin
    final admin = widget.profile.isAdmin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Laporan Kejadian'),
        actions: [
          if (bisaBuat)
            IconButton(
              icon: const Icon(Icons.campaign_outlined),
              onPressed: () => setState(() {
                _tampilBuat = !_tampilBuat;
                _desk = '';
                _lokasi = '';
                _waktuKejadian = null;
                _targetSiswaId = null;
                _lampiranUrl = null;
                _kategoriPilih = kKategori.first;
              }),
            ),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _mulai),
        ],
      ),
      body: Column(
        children: [
          if (bisaBuat && _tampilBuat) _buildFormBuat(),
          Expanded(
            child: _dimuat
                ? AppStates.loading(rows: 4)
                : (_error != null
                    ? AppStates.error(
                        message: _error ?? 'Gagal memuat.', onRetry: _mulai)
                    : _laporan.isEmpty
                        ? AppStates.empty(
                            title: 'Belum ada laporan',
                            message: admin
                                ? 'Laporan dari siswa/ortu akan tampil di sini.'
                                : 'Klik + untuk membuat laporan.',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(18),
                            itemCount: _laporan.length,
                            itemBuilder: (context, i) {
                              final r = _laporan[i];
                              final status =
                                  r['status']?.toString() ?? 'reported';
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              r['kategori']?.toString() ??
                                                  '-',
                                              style: const TextStyle(
                                                  fontSize: 14.5,
                                                  fontWeight:
                                                      FontWeight.w700),
                                            ),
                                          ),
                                          _Badge(
                                            teks: _tampilkanStatus(status),
                                            bg: _warnaStatus(status)
                                                .withValues(alpha: 0.12),
                                            warna: _warnaStatus(status),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        r['deskripsi']?.toString() ?? '-',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      if (r['lokasi'] != null &&
                                          r['lokasi']!.toString().isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            'Lokasi: ${r['lokasi']}',
                                            style: const TextStyle(
                                                fontSize: 11.5,
                                                color: AppColors
                                                    .textSecondary),
                                          ),
                                        ),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'Pelapor: ${_namaReporter(r)} • Kejadian: ${r['waktu_kejadian']?.toString() ?? r['created_at']?.toString() ?? '-'}',
                                          style: const TextStyle(
                                              fontSize: 11.5,
                                              color:
                                                  AppColors.textSecondary),
                                        ),
                                      ),
                                      if (r['target_siswa_id'] != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            'Menyangkut siswa: ${_namaSiswa(r)}',
                                            style: const TextStyle(
                                                fontSize: 11.5,
                                                color: AppColors
                                                    .textSecondary),
                                          ),
                                        ),
                                      if (r['lampiran_url'] != null &&
                                          r['lampiran_url']!
                                              .toString()
                                              .isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.attach_file,
                                                  size: 16,
                                                  color: AppColors
                                                      .textSecondary),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: () => _bukaLampiran(
                                                      r['lampiran_url']
                                                          .toString()),
                                                  child: Text(
                                                    'Buka lampiran',
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color: AppColors
                                                            .primary),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      // Keterangan admin
                                      if (r['keterangan_admin'] != null &&
                                          r['keterangan_admin']!
                                              .toString()
                                              .isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Container(
                                            padding:
                                                const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.06),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'Catatan admin: ${r['keterangan_admin']}',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors
                                                      .textSecondary),
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 10),
                                      if (admin)
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                TextButton(
                                                  onPressed: () => setState(() {
                                                    _detailId = r['id']
                                                        ?.toString();
                                                    _keterangan = '';
                                                  }),
                                                  child: const Text(
                                                      'Tindaklanjuti',
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              AppColors
                                                                  .primary)),
                                                ),
                                                TextButton(
                                                  onPressed: () => _hapus(
                                                      r['id']?.toString() ??
                                                          ''),
                                                  child: const Text('Hapus',
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color: AppColors
                                                              .danger)),
                                                ),
                                              ],
                                            ),
                                            if (_detailId ==
                                                r['id']?.toString())
                                              _buildKeterangan(),
                                          ],
                                        ),
                                      ],
                                    ),
                                ),
                              );
                            },
                          )),
          ),
        ],
      ),
    );
  }

  Widget _buildFormBuat() {
    final bisaPilihSiswa =
        widget.profile.isParent || widget.profile.isAdmin;
    return Card(
      margin: const EdgeInsets.all(18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Laporkan Kejadian',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _kategoriPilih,
              decoration:
                  const InputDecoration(labelText: 'Kategori *'),
              items: [
                for (final k in kKategori)
                  DropdownMenuItem(
                      value: k, child: Text(k, style: const TextStyle(fontSize: 13.5))),
              ],
              onChanged: (v) => setState(() => _kategoriPilih = v ?? kKategori.first),
            ),
            const SizedBox(height: 8),
            if (bisaPilihSiswa)
              DropdownButtonFormField<String>(
                initialValue: _targetSiswaId,
                decoration:
                    const InputDecoration(labelText: 'Siswa terkait (opsional)'),
                items: [
                  for (final s in _siswaMap.values)
                    DropdownMenuItem(
                        value: s['id']?.toString(),
                        child: Text('${s['nama'] ?? '-'}',
                            style: const TextStyle(
                                fontSize: 13.5, overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (v) => setState(() => _targetSiswaId = v),
              ),
            if (bisaPilihSiswa)
              const SizedBox(height: 8),
            TextField(
              onChanged: (v) => _desk = v,
              maxLines: 4,
              decoration: const InputDecoration(
                  labelText: 'Deskripsi kejadian *'),
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => _lokasi = v,
              decoration:
                  const InputDecoration(labelText: 'Lokasi (opsional)'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: now,
                        firstDate: now.subtract(const Duration(days: 365)),
                        lastDate: now,
                      );
                      if (picked != null) {
                        setState(() => _waktuKejadian =
                            picked.toIso8601String().split('.').first);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: 'Waktu kejadian'),
                      child: Text(
                        _waktuKejadian?.toString().substring(0, 10) ??
                            'Pilih tanggal',
                        style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _lampiranUrl == null ? _uploadLampiran : null,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: 'Lampiran (foto/dok)'),
                      child: Text(
                        _lampiranUrl == null
                            ? _sibuk
                                ? 'Mengupload…'
                                : 'Pilih file'
                            : 'Lampiran terpasang ✓',
                        style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_lampiranUrl != null)
              TextButton(
                onPressed: () => setState(() => _lampiranUrl = null),
                child: const Text('Hapus lampiran',
                    style: TextStyle(fontSize: 12, color: AppColors.danger)),
              ),
            const SizedBox(height: 4),
            FilledButton(
              onPressed: _sibuk ? null : _buat,
              child: _sibuk
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2.4))
                  : const Text('Kirim Laporan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeterangan() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            onChanged: (v) => _keterangan = v,
            maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'Catatan tindak lanjut'),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _sibuk
                      ? null
                      : () => _ubahStatus('processed',
                          tampilkanKeterangan: true),
                  child: const Text('Proses',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.warning)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _sibuk
                      ? null
                      : () => _ubahStatus('resolved',
                          tampilkanKeterangan: true),
                  child: const Text('Selesai',
                      style: TextStyle(fontSize: 12, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.teks,
    required this.bg,
    required this.warna,
  });

  final String teks;
  final Color bg;
  final Color warna;

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
            color: warna),
      ),
    );
  }
}
