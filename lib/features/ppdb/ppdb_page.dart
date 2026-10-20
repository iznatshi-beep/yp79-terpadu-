import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/repositories.dart';
import '../../widgets/app_states.dart';
import '../../widgets/common.dart';

/// Halaman PPDB (admin): daftar pendaftar, ubah status, tetapkan hasil.
class PpdbPage extends StatefulWidget {
  const PpdbPage({super.key});

  @override
  State<PpdbPage> createState() => _PpdbPageState();
}

enum _FilterPpdb { semua, draf, verifikasi, lolos, tidakLolos }

extension _FilterPpdbX on _FilterPpdb {
  String get label => switch (this) {
        _FilterPpdb.semua => 'Semua',
        _FilterPpdb.draf => 'Draf',
        _FilterPpdb.verifikasi => 'Verifikasi',
        _FilterPpdb.lolos => 'Lolos',
        _FilterPpdb.tidakLolos => 'Tidak Lolos',
      };

  String? get nilai => switch (this) {
        _FilterPpdb.semua => null,
        _FilterPpdb.draf => 'draf',
        _FilterPpdb.verifikasi => 'verifikasi',
        _FilterPpdb.lolos => 'lolos',
        _FilterPpdb.tidakLolos => 'tidak_lolos',
      };
}

class _PpdbPageState extends State<PpdbPage> {
  bool _memuat = true;
  String? _error;
  List<RowData> _pendaftar = const [];
  _FilterPpdb _filter = _FilterPpdb.semua;
  String _cari = '';

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _memuat = _pendaftar.isEmpty;
      _error = null;
    });
    final hasil = await Repos.ppdbDaftar();
    if (!mounted) return;
    setState(() {
      _pendaftar = hasil.data;
      _error = hasil.error;
      _memuat = false;
    });
  }

  List<RowData> get _terfilter {
    final q = _cari.trim().toLowerCase();
    return [
      for (final p in _pendaftar)
        if ((_filter.nilai == null || p['status'] == _filter.nilai) &&
            (q.isEmpty ||
                (p['nama_calon']?.toString().toLowerCase().contains(q) ?? false) ||
                (p['nomor_registrasi']?.toString().toLowerCase().contains(q) ?? false)))
        p
    ];
  }

  void _pesan(String teks, {bool sukses = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(teks),
        backgroundColor: sukses ? AppColors.success : AppColors.danger,
        duration: const Duration(seconds: 6),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('PPDB - Pendaftar'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _muat,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: TextField(
              onChanged: (v) => setState(() => _cari = v),
              decoration: const InputDecoration(
                hintText: 'Cari nama atau nomor registrasi',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              children: [
                for (final f in _FilterPpdb.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _PilFilter(
                      label: f.label,
                      aktif: _filter == f,
                      onTap: () => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _isi()),
        ],
      ),
    );
  }

  Widget _isi() {
    if (_memuat) {
      return const Padding(padding: EdgeInsets.all(18), child: SkeletonRow());
    }
    if (_error != null) return ErrorState(message: _error!, onRetry: _muat);

    final baris = _terfilter;
    if (baris.isEmpty) {
      return const EmptyState(
        title: 'Belum ada pendaftar',
        message: 'Formulir PPDB publik akan menghasilkan pendaftar di sini.',
        icon: Icons.how_to_reg_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        itemCount: baris.length,
        itemBuilder: (context, i) => _kartu(baris[i]),
      ),
    );
  }

  Widget _kartu(RowData p) {
    final status = p['status']?.toString() ?? 'draf';
    final badge = switch (status) {
      'draf' => (BadgeState.neutral, 'Draf'),
      'verifikasi' => (BadgeState.info, 'Verifikasi'),
      'lolos' => (BadgeState.success, 'Lolos'),
      'tidak_lolos' => (BadgeState.danger, 'Tidak Lolos'),
      _ => (BadgeState.neutral, status),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: appSoftShadow,
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p['nama_calon']?.toString() ?? '-',
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(
                    '${p['nomor_registrasi'] ?? '-'} · '
                    'NISN ${p['nisn_calon'] ?? '-'} · '
                    '${p['jenjang'] ?? '-'}',
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.muted),
                  ),
                  const SizedBox(height: 6),
                  StatusBadge(label: status, state: badge.$1),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) => _aksi(p, v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'verifikasi', child: Text('Tandai Verifikasi')),
                const PopupMenuItem(value: 'lolos', child: Text('Tetapkan Lolos')),
                const PopupMenuItem(
                    value: 'tidak_lolos', child: Text('Tetapkan Tidak Lolos')),
              ],
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _aksi(RowData p, String aksi) async {
    final id = p['id']?.toString() ?? '';
    if (id.isEmpty) return;

    if (['verifikasi', 'lolos', 'tidak_lolos'].contains(aksi)) {
      // lolos/tidak_lolos memakai ppdb_set_hasil: selain mengubah status,
      // mencatat hasil ke admission_results (riwayat keputusan).
      if (aksi == 'verifikasi') {
        final err = await Repos.ppdbSetStatus(id, 'verifikasi');
        _pesan(err ?? 'Status diperbarui menjadi verifikasi.',
            sukses: err == null);
        await _muat();
        return;
      }
      final yakin = await showConfirmDialog(
        context,
        judul: aksi == 'lolos'
            ? 'Tetapkan hasil LOLOS?'
            : 'Tetapkan hasil TIDAK LOLOS?',
        pesan: 'Keputusan ini tercatat sebagai hasil akhir seleksi pendaftar.',
        tombolYa: 'Tetapkan',
        warnColor:
            aksi == 'lolos' ? AppColors.success : AppColors.danger,
      );
      if (!yakin) return;
      final hasil = await Repos.ppdbSetHasil(id, aksi, publikasi: false);
      _pesan(hasil ?? 'Hasil "$aksi" ditetapkan.', sukses: hasil == null);
      await _muat();
    }
  }
}


class _PilFilter extends StatelessWidget {
  const _PilFilter({
    required this.label,
    required this.aktif,
    required this.onTap,
  });

  final String label;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: aktif ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: aktif ? null : appSoftShadow,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
            color: aktif ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
