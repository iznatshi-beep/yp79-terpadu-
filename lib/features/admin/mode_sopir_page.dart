import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/repositories.dart';
import '../../services/tracker_bus.dart';
import '../../widgets/app_states.dart';
import '../../widgets/common.dart';

/// Mode sopir: pilih bus yang dikendarai, nyalakan tracker GPS.
/// Posisi terkirim otomatis tiap 20 detik ke server; admin melihat
/// posisi live di halaman Bus & GPS.
class ModeSopirPage extends StatefulWidget {
  const ModeSopirPage({super.key});

  @override
  State<ModeSopirPage> createState() => _ModeSopirPageState();
}

class _ModeSopirPageState extends State<ModeSopirPage> {
  bool _memuat = true;
  String? _error;
  List<RowData> _bus = const [];
  bool _aktif = false;
  Timer? _tick; // refresh indikator tiap detik (durasi & jumlah kirim)

  @override
  void initState() {
    super.initState();
    _muat();
    _aktif = TrackerBus.berjalan;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_aktif != TrackerBus.berjalan) setState(() => _aktif = TrackerBus.berjalan);
      else if (_aktif) setState(() {}); // refresh counter
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() {
      _memuat = _bus.isEmpty;
      _error = null;
    });
    final hasil = await Repos.vehicles();
    if (!mounted) return;
    setState(() {
      _bus = hasil.data;
      _error = hasil.error;
      _memuat = false;
    });
  }

  Future<void> _mulai(RowData v) async {
    final id = v['id']?.toString() ?? '';
    final err = await TrackerBus.start(id);
    if (!mounted) return;
    setState(() => _aktif = TrackerBus.berjalan);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err), backgroundColor: AppColors.danger));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Tracker aktif untuk ${v['plat_nomor'] ?? 'bus'}.'),
        backgroundColor: AppColors.success));
  }

  void _hentikan() {
    TrackerBus.stop();
    setState(() => _aktif = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Mode Sopir')),
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
        message: 'Minta admin menambahkan bus terlebih dahulu.',
        icon: Icons.directions_bus_outlined,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        if (_aktif) _kartuAktif() else ..._kartuPilihan(),
      ],
    );
  }

  List<Widget> get _kartuPilihan => [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Pilih bus yang Anda kemudikan, lalu nyalakan tracker. '
            'Posisi terkirim otomatis tiap 20 detik selama halaman ini terbuka.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ),
        for (final v in _bus)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                boxShadow: appSoftShadow,
              ),
              child: ListTile(
                leading: const Icon(Icons.directions_bus_rounded,
                    color: AppColors.primary),
                title: Text('${v['plat_nomor'] ?? '-'} (${v['jenis'] ?? '-'})',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: AppColors.ink)),
                subtitle: Text('Sopir: ${v['sopir_nama'] ?? '-'}',
                    style:
                        const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                trailing: const Icon(Icons.play_circle_fill_rounded,
                    color: AppColors.success),
                onTap: () => _mulai(v),
              ),
            ),
          ),
      ];

  Widget _kartuAktif() {
    final v = _bus.firstWhere(
      (b) => b['id']?.toString() == TrackerBus.vehicleIdAktif,
      orElse: () => _bus.first,
    );
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: appSoftShadow,
        border: Border.all(color: AppColors.success, width: 1.5),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.my_location_rounded, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tracker aktif — ${v['plat_nomor'] ?? '-'}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Posisi terkirim: ${TrackerBus.jumlahTerkirim} kali\n'
            'Dimulai: ${_fmtJam(TrackerBus.mulaiPada)}\n'
            '${TrackerBus.errorTerakhir != null ? 'Catatan: ${TrackerBus.errorTerakhir}' : 'Semua posisi terkirim dengan baik.'}',
            style: const TextStyle(
                fontSize: 12.5, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 6),
          const Text(
            'Jaga halaman ini tetap terbuka selama mengemudi. '
            'Android bisa menghentikan pelacakan bila app ditutup total.',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: _hentikan,
            icon: const Icon(Icons.stop_circle_rounded),
            label: const Text('Selesai mengemudi'),
          ),
        ],
      ),
    );
  }

  String _fmtJam(DateTime? t) {
    if (t == null) return '-';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
  }
}
