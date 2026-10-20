import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/repositories.dart';
import '../../widgets/app_states.dart';
import '../../widgets/common.dart';

/// Master data siswa (admin): daftar semua akun siswa + IMPORT MASSAL CSV.
///
/// Format CSV (satu baris = satu siswa): NIS,Nama,Email,Kelas(opsional)
/// Contoh:
///   2026001,Budi Santoso,budi@yp79.id,7A
///   2026002,Siti Aminah,siti@yp79.id,7A
///
/// - Kelas dicocokkan ke nama kelas yang sudah ada di Data Master.
/// - Kata sandi awal tiap siswa: yp79 + NIS (disampaikan ke siswa; wajib
///   diganti saat login pertama).
/// - Baris yang gagal (email terpakai, duplikat) dilaporkan per baris.
class MasterSiswaPage extends StatefulWidget {
  const MasterSiswaPage({super.key});

  @override
  State<MasterSiswaPage> createState() => _MasterSiswaPageState();
}

class _MasterSiswaPageState extends State<MasterSiswaPage> {
  bool _memuat = true;
  String? _error;
  List<RowData> _siswa = const [];
  Map<String, String> _kelasNama = const {};
  String _cari = '';

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _memuat = _siswa.isEmpty);
    final hasil = await Repos.listSiswa();
    final kelas = await Repos.listKelas();
    if (!mounted) return;
    setState(() {
      _siswa = hasil.data;
      _kelasNama = {
        for (final k in kelas.data)
          k['id'].toString(): k['nama']?.toString() ?? '-'
      };
      _memuat = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Data Siswa')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _menuTambah(context),
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('Tambah / Import'),
      ),
      body: _isi(),
    );
  }

  Widget _isi() {
    if (_memuat) {
      return const Padding(padding: EdgeInsets.all(18), child: SkeletonRow());
    }
    final q = _cari.trim().toLowerCase();
    final rows = [
      for (final s in _siswa)
        if (q.isEmpty ||
            (s['nama']?.toString().toLowerCase().contains(q) ?? false) ||
            (s['email']?.toString().toLowerCase().contains(q) ?? false))
          s
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: TextField(
            onChanged: (v) => setState(() => _cari = v),
            decoration: InputDecoration(
              hintText: 'Cari nama atau email (${_siswa.length} siswa)',
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
        ),
        Expanded(child: _daftar(rows)),
      ],
    );
  }

  Widget _daftar(List<RowData> rows) {
    if (rows.isEmpty) {
      return EmptyState(
        title: _siswa.isEmpty ? 'Belum ada akun siswa' : 'Tidak ada yang cocok',
        message: _siswa.isEmpty
            ? 'Tekan tombol Tambah untuk memasukkan siswa satu-per-satu, '
                'atau Import massal dari CSV.'
            : 'Coba kata kunci lain.',
        icon: Icons.school_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _muat(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 96),
        itemCount: rows.length,
        itemBuilder: (context, i) => _kartu(rows[i]),
      ),
    );
  }

  Widget _kartu(RowData s) {
    final kelasId = s['kelas_id']?.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: appSoftShadow,
        ),
        child: Row(
          children: [
            InitialAvatar(name: s['nama']?.toString() ?? '?', size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s['nama']?.toString() ?? '-',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink)),
                  Text(
                      '${s['email']?.toString() ?? '-'}'
                      '${kelasId != null ? ' · ${_kelasNama[kelasId] ?? ''}' : ''}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _menuTambah(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_alt_1_rounded),
              title: const Text('Tambah satu siswa'),
              subtitle: const Text('Email + NIS + nama (akun langsung aktif)'),
              onTap: () {
                Navigator.pop(ctx);
                _formTambahSatu(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_rounded),
              title: const Text('Import massal (CSV)'),
              subtitle: const Text('Tempel daftar: NIS,Nama,Email,Kelas'),
              onTap: () {
                Navigator.pop(ctx);
                _formImportCsv(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _formTambahSatu(BuildContext context) async {
    final namaCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final nisCtrl = TextEditingController();
    String? kelasSel;
    final kelas = await Repos.listKelas();
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setL) => AlertDialog(
          title: const Text('Tambah siswa'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: namaCtrl,
                  decoration: const InputDecoration(labelText: 'Nama lengkap')),
              const SizedBox(height: 10),
              TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 10),
              TextField(
                  controller: nisCtrl,
                  decoration: const InputDecoration(labelText: 'NIS')),
              if (kelas.data.isNotEmpty) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: kelasSel,
                  decoration: const InputDecoration(labelText: 'Kelas (opsional)'),
                  items: [
                    for (final k in kelas.data)
                      DropdownMenuItem(
                          value: k['id'].toString(),
                          child: Text(k['nama']?.toString() ?? '-')),
                  ],
                  onChanged: (v) => setL(() => kelasSel = v),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Simpan')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;

    final err = await Repos.adminCreateUser(
      email: emailCtrl.text.trim(),
      nama: namaCtrl.text.trim(),
      role: 'siswa',
      password: 'yp79-${nisCtrl.text.trim()}',
      identitas: nisCtrl.text.trim(),
      kelasId: kelasSel,
    );
    if (!context.mounted) return;
    if (err == null) {
      showToast(context, 'Siswa ditambahkan. Sandi awal: yp79-${nisCtrl.text.trim()}',
          color: AppColors.success);
      _muat();
    } else {
      showToast(context, err, color: AppColors.danger);
    }
  }

  Future<void> _formImportCsv(BuildContext context) async {
    final csvCtrl = TextEditingController();
    final kelas = await Repos.listKelas();
    if (!context.mounted) return;
    final kelasByNama = {
      for (final k in kelas.data) (k['nama']?.toString() ?? '').toLowerCase(): k['id'].toString()
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import massal siswa (CSV)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Satu baris = satu siswa:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryBg,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Text(
                  'NIS,Nama,Email,Kelas\n'
                  '2026001,Budi Santoso,budi@yp79.id,7A\n'
                  '2026002,Siti Aminah,siti@yp79.id,7A',
                  style: TextStyle(
                      fontSize: 11.5, fontFamily: 'monospace',
                      color: AppColors.ink),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                  'Sandi awal tiap siswa: yp79 + NIS. Baris gagal '
                  '(email terpakai, dsb.) dilaporkan setelah selesai.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              TextField(
                controller: csvCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Tempel data CSV di sini…',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Import')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    // Proses import
    final baris = csvCtrl.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (baris.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(strokeWidth: 2),
          SizedBox(width: 16),
          Expanded(child: Text('Mengimpor siswa…')),
        ]),
      ),
    );

    var sukses = 0;
    final gagal = <({int baris, String alasan})>[];
    for (var i = 0; i < baris.length; i++) {
      final kolom = baris[i].split(',').map((c) => c.trim()).toList();
      if (kolom.length < 3) {
        gagal.add((baris: i + 1, alasan: 'format salah (butuh NIS,Nama,Email)'));
        continue;
      }
      final nis = kolom[0];
      final nama = kolom[1];
      final email = kolom[2];
      String? kelasId;
      if (kolom.length >= 4 && kolom[3].isNotEmpty) {
        kelasId = kelasByNama[kolom[3].toLowerCase()];
      }
      final err = await Repos.adminCreateUser(
        email: email,
        nama: nama,
        role: 'siswa',
        password: 'yp79-$nis',
        identitas: nis,
        kelasId: kelasId,
      );
      if (err == null) {
        sukses++;
      } else {
        gagal.add((baris: i + 1, alasan: err));
      }
    }

    if (!mounted) return;
    Navigator.pop(context); // tutup dialog loading
    _muat();

    // Laporan hasil
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hasil import'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Berhasil: $sukses siswa',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.success)),
              if (gagal.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Gagal:',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                for (final g in gagal)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Baris ${g.baris}: ${g.alasan}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.danger)),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }
}
