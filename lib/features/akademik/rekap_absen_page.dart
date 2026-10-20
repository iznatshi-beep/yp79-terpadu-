import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/session_profile.dart';
import '../../core/theme.dart';
import '../../services/repositories.dart';
import '../../widgets/app_states.dart';
import '../../widgets/common.dart';

enum _Periode { harian, mingguan, bulanan }

/// Rekap absensi harian / mingguan / bulanan.
/// Setiap murid yang absen (manual atau QR) otomatis masuk rekap.
/// Tombol unduh menghasilkan CSV (langsung terbuka di Excel) dan
/// membuka share sheet untuk menyimpan / mengirim.
class RekapAbsenPage extends StatefulWidget {
  const RekapAbsenPage({super.key, required this.profile});

  final SessionProfile profile;

  @override
  State<RekapAbsenPage> createState() => _RekapAbsenPageState();
}

class _RekapAbsenPageState extends State<RekapAbsenPage> {
  _Periode _periode = _Periode.harian;
  DateTime _acuan = DateTime.now();
  bool _memuat = true;
  String? _error;
  List<RowData> _rows = const [];
  Map<String, String> _mapNama = const {};

  String get _labelPeriode => switch (_periode) {
        _Periode.harian => 'harian',
        _Periode.mingguan => 'mingguan',
        _Periode.bulanan => 'bulanan',
      };

  DateTime get _mulaiPeriode {
    switch (_periode) {
      case _Periode.harian:
        return DateTime(_acuan.year, _acuan.month, _acuan.day);
      case _Periode.mingguan:
        return _acuan.subtract(Duration(days: _acuan.weekday - 1));
      case _Periode.bulanan:
        return DateTime(_acuan.year, _acuan.month, 1);
    }
  }

  DateTime get _akhirPeriode {
    switch (_periode) {
      case _Periode.harian:
        return _acuan;
      case _Periode.mingguan:
        return _mulaiPeriode.add(const Duration(days: 6));
      case _Periode.bulanan:
        return DateTime(_acuan.year, _acuan.month + 1, 0);
    }
  }

  String get _judulPeriode {
    if (_periode == _Periode.harian) {
      return '${_acuan.day}/${_acuan.month}/${_acuan.year}';
    }
    final a = _mulaiPeriode;
    final b = _akhirPeriode;
    return '${a.day}/${a.month} - ${b.day}/${b.month}/${b.year}';
  }

  Future<void> _muat() async {
    setState(() => _memuat = true);
    final hasil = await Repos.attendance(
      mulai: _mulaiPeriode,
      sampai: _akhirPeriode,
    );
    if (!mounted) return;
    final ids = [
      for (final r in hasil.data)
        if (r['student_user_id'] != null) r['student_user_id'].toString()
    ].toSet().toList();
    final nama = await Repos.profilesByIds(ids);
    if (!mounted) return;
    setState(() {
      _rows = hasil.data;
      _mapNama = {
        for (final p in nama.data)
          p['id'].toString(): p['nama']?.toString() ?? '-'
      };
      _memuat = false;
    });
  }

  Future<void> _unduh() async {
    final csv = const ListToCsvConverter().convert([
      ['Nama', 'Tanggal', 'Status', 'Metode', 'Jam Check-in'],
      for (final r in _rows)
        [
          _mapNama[r['student_user_id']?.toString()] ?? '-',
          r['tanggal']?.toString() ?? '',
          r['status']?.toString() ?? '-',
          r['metode']?.toString() ?? '-',
          (r['jam_checkin']?.toString() ?? '').split('.').first,
        ],
    ]);
    await Share.shareXFiles(
      [
        XFile.fromData(
          utf8.encode('\uFEFF$csv'),
          mimeType: 'text/csv',
          name: 'rekap_absen_$_labelPeriode.csv',
        ),
      ],
      subject: 'Rekap absen $_labelPeriode ($_judulPeriode)',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rekap Absen'),
        actions: [
          IconButton(
            tooltip: 'Unduh / bagikan CSV (Excel)',
            onPressed: _rows.isEmpty ? null : _unduh,
            icon: const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: SegmentedButton<_Periode>(
              segments: const [
                ButtonSegment(value: _Periode.harian, label: Text('Harian')),
                ButtonSegment(
                    value: _Periode.mingguan, label: Text('Mingguan')),
                ButtonSegment(
                    value: _Periode.bulanan, label: Text('Bulanan')),
              ],
              selected: {_periode},
              onSelectionChanged: (s) {
                setState(() => _periode = s.first);
                _muat();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: 'Periode sebelumnya',
                  onPressed: () {
                    setState(() {
                      switch (_periode) {
                        case _Periode.harian:
                          _acuan = _acuan.subtract(const Duration(days: 1));
                        case _Periode.mingguan:
                          _acuan = _acuan.subtract(const Duration(days: 7));
                        case _Periode.bulanan:
                          _acuan = DateTime(_acuan.year, _acuan.month, 0);
                      }
                    });
                    _muat();
                  },
                ),
                Expanded(
                  child: Text(
                    '$_judulPeriode (${_rows.length} catatan)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () {
                    setState(() {
                      switch (_periode) {
                        case _Periode.harian:
                          _acuan = _acuan.add(const Duration(days: 1));
                        case _Periode.mingguan:
                          _acuan = _acuan.add(const Duration(days: 7));
                        case _Periode.bulanan:
                          _acuan = DateTime(_acuan.year, _acuan.month + 2, 0);
                      }
                    });
                    _muat();
                  },
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
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _muat);
    }
    if (_rows.isEmpty) {
      return const EmptyState(
        title: 'Belum ada data',
        message: 'Belum ada presensi pada periode ini.',
        icon: Icons.event_note_outlined,
      );
    }
    // Agregasi per siswa
    final map = <String, Map<String, int>>{};
    for (final r in _rows) {
      final id = r['student_user_id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final status = r['status']?.toString() ?? '-';
      final agg = map.putIfAbsent(id, () => {});
      agg[status] = (agg[status] ?? 0) + 1;
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      children: [
        for (final entry in map.entries)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: appSoftShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_mapNama[entry.key] ?? entry.key,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    StatusBadge(
                        label: 'H ${entry.value['hadir'] ?? 0}',
                        state: BadgeState.success),
                    StatusBadge(
                        label: 'T ${entry.value['terlambat'] ?? 0}',
                        state: BadgeState.warning),
                    StatusBadge(
                        label: 'I ${entry.value['izin'] ?? 0}',
                        state: BadgeState.info),
                    StatusBadge(
                        label: 'S ${entry.value['sakit'] ?? 0}',
                        state: BadgeState.neutral),
                    StatusBadge(
                        label: 'A ${entry.value['alpa'] ?? 0}',
                        state: BadgeState.danger),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
