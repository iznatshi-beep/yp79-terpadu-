import 'package:flutter/material.dart';

import '../../core/models/session_profile.dart';
import '../../core/theme.dart';
import '../../services/repositories.dart';
import '../../widgets/app_states.dart';
import '../../widgets/common.dart';

/// Alokasi bus: admin pilih siswa -> kendaraan + rute.
/// Siswa/ortu bisa lihat kendaraan + rute masing-masing.
class AlokasiBusPage extends StatefulWidget {
  const AlokasiBusPage({super.key, required this.profile});

  final SessionProfile profile;

  @override
  State<AlokasiBusPage> createState() => _AlokasiBusPageState();
}

class _AlokasiBusPageState extends State<AlokasiBusPage> {
  bool _dimuat = false;
  bool _sibuk = false;
  String? _error;

  List<RowData> _alokasi = [];
  List<RowData> _bus = [];
  List<RowData> _siswa = [];

  // form
  String? _siswaPilih;
  String? _busPilih;
  String _ruteMulai = '';
  String _ruteTujuan = '';

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
      Repos.vehicleAssignments(),
      Repos.vehicles(),
      Repos.listSiswa(),
    ]);
    final a = results[0];
    final b = results[1];
    final s = results[2];
    if (!mounted) return;
    if (a.error != null) {
      setState(() {
        _error = a.error;
        _dimuat = true;
      });
      return;
    }
    setState(() {
      _alokasi = a.data;
      _bus = b.data;
      _siswa = s.data;
      _dimuat = true;
    });
  }

  Future<void> _alokasi() async {
    if (_siswaPilih == null || _busPilih == null) {
      showToast(context, 'Pilih siswa & kendaraan.',
          color: AppColors.danger);
      return;
    }
    setState(() => _sibuk = true);
    final err = await Repos.alokasiBus(
      vehicleId: _busPilih!,
      studentUserId: _siswaPilih!,
      ruteMulai: _ruteMulai.isEmpty ? null : _ruteMulai,
      ruteTujuan: _ruteTujuan.isEmpty ? null : _ruteTujuan,
    );
    if (!mounted) return;
    setState(() => _sibuk = false);
    if (err == null) {
      showToast(context, 'Alokasi tersimpan.');
      await _muat();
    } else {
      showToast(context, err, color: AppColors.danger);
    }
  }

  Future<void> _hapus(String id) async {
    final ok = await showConfirmDialog(
      context,
      judul: 'Hapus Alokasi',
      pesan: 'Siswa tidak lagi tercatat naik kendaraan ini.',
      tombolYa: 'Hapus',
      warnColor: AppColors.danger,
    );
    if (!ok) return;
    final err = await Repos.hapusAlokasiBus(id);
    if (!mounted) return;
    if (err == null) {
      showToast(context, 'Alokasi dihapus.');
      await _muat();
    } else {
      showToast(context, err, color: AppColors.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = widget.profile.isAdmin;
    // ortu/siswa hanya lihat alokasi sendiri
    final daftar = admin
        ? _alokasi
        : _alokasi.where((a) {
            final sid = a['student_user_id']?.toString();
            if (widget.profile.isStudent) {
              return sid == widget.profile.studentId;
            }
            return widget.profile.parentStudentIds.contains(sid);
          }).toList();

    if (!_dimuat) return AppStates.loading(rows: 4);
    if (_error != null) {
      return AppStates.error(message: _error!, onRetry: _muat);
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Alokasi Bus'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(onPressed: _muat, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (admin)
            Card(
              color: AppColors.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                side: const BorderSide(color: AppColors.line),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tambah Alokasi',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _siswaPilih,
                      decoration: const InputDecoration(
                          labelText: 'Siswa',
                          border: OutlineInputBorder()),
                      items: _siswa
                          .map((s) =>
                              DropdownMenuItem(
                                value: s['id']?.toString(),
                                child: Text(s['nama']?.toString() ?? ''),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _siswaPilih = v),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _busPilih,
                      decoration: const InputDecoration(
                          labelText: 'Kendaraan',
                          border: OutlineInputBorder()),
                      items: _bus
                          .map((b) =>
                              DropdownMenuItem(
                                value: b['id']?.toString(),
                                child: Text(b['plat_nomor']?.toString() ?? ''),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _busPilih = v),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      decoration: const InputDecoration(
                          labelText: 'Rute Asal',
                          border: OutlineInputBorder()),
                      onChanged: (v) => setState(() => _ruteMulai = v),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      decoration: const InputDecoration(
                          labelText: 'Rute Tujuan',
                          border: OutlineInputBorder()),
                      onChanged: (v) => setState(() => _ruteTujuan = v),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _sibuk ? null : _alokasi,
                        child: const Text('Simpan Alokasi',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (daftar.isEmpty)
            AppStates.empty(
              title: 'Belum ada alokasi',
              message: admin
                  ? 'Tambahkan siswa ke kendaraan di form di atas.'
                  : 'Kamu belum tercatat naik kendaraan.',
            )
          else
            ...daftar.map((a) {
              final sp = (a['student_profiles'] as Map?) ?? const {};
              final v = (a['vehicles'] as Map?) ?? const {};
              final nama = sp['nama_lengkap']?.toString() ?? 'Siswa';
              final nis = sp['nis']?.toString() ?? '';
              final plat = v['plat_nomor']?.toString() ?? 'Bus';
              final rm = a['rute_mulai']?.toString();
              final rt = a['rute_tujuan']?.toString();
              final id = a['id']?.toString() ?? '';
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: AppColors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  side: const BorderSide(color: AppColors.line),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primaryBg,
                    child: Icon(Icons.directions_bus,
                        color: AppColors.primary, size: 22),
                  ),
                  title:
                      Text('$nama ($nis)', style: const TextStyle(fontSize: 13.5)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Naik $plat',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                      if ((rm?.isNotEmpty ?? false) ||
                          (rt?.isNotEmpty ?? false))
                        Text(
                            [
                              if (rm?.isNotEmpty ?? false) 'Dari: $rm',
                              if (rt?.isNotEmpty ?? false) 'Tujuan: $rt',
                            ].join('  •  '),
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.muted)),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: admin
                      ? IconButton(
                          onPressed: () => _hapus(id),
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: AppColors.danger,
                        )
                      : null,
                ),
              );
            }),
        ],
      ),
    );
  }
}
