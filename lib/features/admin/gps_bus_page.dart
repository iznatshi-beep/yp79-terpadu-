import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/repositories.dart';
import '../../widgets/app_states.dart';
import '../../widgets/common.dart';

/// Halaman Bus & GPS (admin): kelola armada bus sekolah.
///
/// Dokumen client meminta pelacak GPS live. Data posisi MASUK lewat
/// `vehicle_locations` dari sumber nyata (perangkat GPS / app pengemudi).
/// Halaman ini adalah sisi ADMIN: kelola bus, status, kapasitas, dan lihat
/// posisi terakhir yang tercatat. TANPA sumber GPS nyata, halaman menampilkan
/// status jujur 'belum ada pembaruan' - tidak memalsukan posisi.
class GpsBusPage extends StatefulWidget {
  const GpsBusPage({super.key});

  @override
  State<GpsBusPage> createState() => _GpsBusPageState();
}

class _GpsBusPageState extends State<GpsBusPage> {
  bool _memuat = true;
  String? _error;
  List<RowData> _bus = const [];
  Map<String, RowData> _lokasi = {}; // vehicle_id -> lokasi terbaru

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _memuat = _bus.isEmpty;
      _error = null;
    });
    final hasil = await Repos.vehicles();
    if (!mounted) return;
    final lokasi = await Repos.lokasiTerakhirSemuaBus();
    if (!mounted) return;
    setState(() {
      _bus = hasil.data;
      _error = hasil.error;
      _lokasi = lokasi;
      _memuat = false;
    });
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
        title: const Text('Bus & GPS'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _muat,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _bukaFormTambah,
        icon: const Icon(Icons.add_road_rounded, size: 20),
        label: const Text('Tambah bus'),
      ),
      body: _isi(),
    );
  }

  Widget _isi() {
    if (_memuat) {
      return const Padding(padding: EdgeInsets.all(18), child: SkeletonRow());
    }
    if (_error != null) return ErrorState(message: _error!, onRetry: _muat);
    if (_bus.isEmpty) {
      return const EmptyState(
        title: 'Belum ada bus terdaftar',
        message:
            'Tambahkan bus, isi sopir, dan kapasitas. Data posisi live akan '
            'tampil bila perangkat GPS terpasang di kendaraan.',
        icon: Icons.directions_bus_outlined,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(18),
      itemCount: _bus.length,
      itemBuilder: (context, i) => _kartu(_bus[i]),
    );
  }

  Widget _kartu(RowData v) {
    final status = v['status']?.toString() ?? 'aktif';
    final lokasi = _lokasi[v['id']?.toString()];
    final badge = switch (status) {
      'aktif' => (BadgeState.success, 'Aktif'),
      'perbaikan' => (BadgeState.warning, 'Perbaikan'),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${v['plat_nomor'] ?? '-'} (${v['jenis'] ?? '-'})',
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink)),
                      const SizedBox(height: 2),
                      Text(
                        'Sopir: ${v['sopir_nama'] ?? '-'} · '
                        'Kapasitas ${v['kapasitas'] ?? '-'}',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                StatusBadge(label: badge.$2, state: badge.$1),
                PopupMenuButton<String>(
                  onSelected: (a) => _aksi(v, a),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'ubah_status', child: Text('Ubah status')),
                  ],
                  icon: const Icon(Icons.more_vert_rounded),
                ),
              ],
            ),
            // Lokasi GPS terakhir (bila ada pembaruan nyata dari perangkat).
            if (lokasi != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Posisi: ${lokasi!['lat']}, ${lokasi!['lng']} · '
                  'per ${lokasi!['terekam_pada']}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.muted),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Posisi belum tersedia (perangkat GPS belum terpasang).',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _aksi(RowData v, String aksi) async {
    // Ubah status bus (aktif <-> perbaikan) lewat RPC admin.
    final id = v['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final statusBaru = v['status'] == 'aktif' ? 'perbaikan' : 'aktif';
    final err = await Repos.ubahStatusBus(id, statusBaru);
    _pesan(err ?? 'Status bus diperbarui menjadi $statusBaru.', sukses: err == null);
    await _muat();
  }

  Future<void> _bukaFormTambah() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _FormBus(),
    );
    await _muat();
  }
}

class _FormBus extends StatefulWidget {
  const _FormBus();

  @override
  State<_FormBus> createState() => _FormBusState();
}

class _FormBusState extends State<_FormBus> {
  final _plat = TextEditingController();
  final _sopir = TextEditingController();
  final _kapasitas = TextEditingController();
  String _jenis = 'bus';
  bool _sibuk = false;
  String? _error;

  @override
  void dispose() {
    _plat.dispose();
    _sopir.dispose();
    _kapasitas.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (_plat.text.trim().isEmpty || _kapasitas.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Plat nomor dan kapasitas wajib diisi.')));
      return;
    }
    final err = await Repos.tambahBus(
      plat: _plat.text.trim(),
      jenis: _jenis,
      sopir: _sopir.text.trim().isEmpty ? null : _sopir.text.trim(),
      kapasitas: int.tryParse(_kapasitas.text.trim()) ?? 0,
    );
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.danger));
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _plat,
              decoration: const InputDecoration(labelText: 'Plat nomor'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sopir,
              decoration: const InputDecoration(labelText: 'Nama sopir'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _kapasitas,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Kapasitas kursi'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _jenis,
              decoration: const InputDecoration(labelText: 'Jenis'),
              items: const [
                DropdownMenuItem(value: 'bus', child: Text('Bus')),
                DropdownMenuItem(value: 'minibus', child: Text('Minibus')),
                DropdownMenuItem(value: 'van', child: Text('Van')),
              ],
              onChanged: (v) => setState(() => _jenis = v ?? 'bus'),
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
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
