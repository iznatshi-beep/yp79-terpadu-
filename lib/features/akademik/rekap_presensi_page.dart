import 'dart:io';

import 'package:excel/excel.dart' hide Border, Color;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/session_profile.dart';
import '../../../core/theme.dart';
import '../../../services/repositories.dart';
import '../../../widgets/app_states.dart';
import '../../../widgets/common.dart';

/// Rekap presensi per kelas: harian / mingguan / bulanan.
/// Tabel per siswa (hadir, terlambat, izin, sakit, alpa) + unduh XLSX/CSV
/// yang dibagikan lewat share sheet Android.
class RekapPresensiPage extends StatefulWidget {
  const RekapPresensiPage({super.key, required this.profile});

  final SessionProfile profile;

  @override
  State<RekapPresensiPage> createState() => _RekapPresensiPageState();
}

enum _Periode { harian, mingguan, bulanan }

extension _PeriodeX on _Periode {
  String get label => switch (this) {
        _Periode.harian => 'Harian',
        _Periode.mingguan => 'Mingguan',
        _Periode.bulanan => 'Bulanan',
      };
}

class _RekapPresensiPageState extends State<RekapPresensiPage> {
  _Periode _periode = _Periode.harian;
  bool _memuat = true;
  String? _error;
  List<RowData> _kelas = const [];
  String? _kelasId;
  DateTime _tanggal = DateTime.now();

  /// Baris rekap per siswa.
  List<_RekapBaris> _rekap = const [];

  DateTime get _mulaiPeriode => switch (_periode) {
        _Periode.harian => DateTime(
            _tanggal.year, _tanggal.month, _tanggal.day),
        _Periode.mingguan => _tanggal.subtract(
            Duration(days: _tanggal.weekday - 1)),
        _Periode.bulanan => DateTime(_tanggal.year, _tanggal.month, 1),
      };

  DateTime get _akhirPeriode => switch (_periode) {
        _Periode.harian => _mulaiPeriode,
        _Periode.mingguan => _mulaiPeriode.add(const Duration(days: 6)),
        _Periode.bulanan =>
          DateTime(_tanggal.year, _tanggal.month + 1, 0),
      };

  String get _judulPeriode => switch (_periode) {
        _Periode.harian => _fmt(_mulaiPeriode),
        _Periode.mingguan =>
          '${_fmt(_mulaiPeriode)} - ${_fmt(_akhirPeriode)}',
        _Periode.bulanan =>
          '${_bulan(_tanggal.month)} ${_tanggal.year}',
      };

  String _fmt(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';

  String _bulan(int m) => const [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
      ][m - 1];

  @override
  void initState() {
    super.initState();
    _muatKelas();
  }

  Future<void> _muatKelas() async {
    setState(() {
      _memuat = true;
      _error = null;
    });
    final kelas = await Repos.classes();
    if (!mounted) return;
    setState(() {
      _kelas = kelas.data;
      if (_kelasId == null && _kelas.isNotEmpty) {
        _kelasId = _kelas.first['id'].toString();
      }
    });
    if (_kelasId != null) {
      await _muatRekap();
    } else {
      setState(() => _memuat = false);
    }
  }

  Future<void> _muatRekap() async {
    if (_kelasId == null) return;
    setState(() => _memuat = true);

    // Semua siswa kelas (termasuk yang belum presensi = alpa).
    final siswa = await Repos.classStudents(_kelasId!);
    if (!mounted) return;

    final hasil = await Repos.attendance(
      classId: _kelasId,
      mulai: _mulaiPeriode,
      sampai: _akhirPeriode.add(const Duration(days: 1)),
    );
    if (!mounted) return;

    // Kelompokkan record per siswa
    final byUid = <String, List<RowData>>{};
    for (final r in hasil.data) {
      final uid = r['student_user_id']?.toString() ?? '';
      if (uid.isNotEmpty) (byUid[uid] ??= []).add(r);
    }

    final rekap = <_RekapBaris>[];
    for (final s in siswa.data) {
      final uid = s['student_user_id']?.toString() ?? '';
      final prof = s['student_profiles'];
      final nama = (prof is Map ? prof['nama_lengkap'] : null)?.toString() ?? '-';
      final nis = (prof is Map ? prof['nis'] : null)?.toString() ?? '';
      final recs = byUid[uid] ?? const [];
      int hitung(String status) =>
          recs.where((r) => r['status']?.toString() == status).length;
      rekap.add(_RekapBaris(
        uid: uid,
        nis: nis,
        nama: nama,
        hadir: hitung('hadir'),
        terlambat: hitung('terlambat'),
        izin: hitung('izin'),
        sakit: hitung('sakit'),
        alpa: hitung('alpa'),
        totalHari: recs.length,
      ));
    }

    setState(() {
      _rekap = rekap;
      _memuat = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Rekap Presensi')),
      body: Column(
        children: [
          // Pemilih kelas
          if (_kelas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: DropdownButtonFormField<String>(
                initialValue: _kelasId,
                decoration: const InputDecoration(labelText: 'Kelas'),
                items: [
                  for (final k in _kelas)
                    DropdownMenuItem(
                        value: k['id'].toString(),
                        child: Text(k['nama']?.toString() ?? '-')),
                ],
                onChanged: (v) {
                  setState(() => _kelasId = v);
                  _muatRekap();
                },
              ),
            ),
          // Pemilih periode
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            child: SegmentedButton<_Periode>(
              segments: [
                for (final p in _Periode.values)
                  ButtonSegment(value: p, label: Text(p.label)),
              ],
              selected: {_periode},
              onSelectionChanged: (s) {
                setState(() => _periode = s.first);
                _muatRekap();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(_judulPeriode,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textSecondary)),
            ),
          ),
          Expanded(child: _tabel()),
        ],
      ),
      bottomNavigationBar: _rekap.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _unduh(context, xlsx: true),
                        icon: const Icon(Icons.grid_on_rounded, size: 18),
                        label: const Text('Unduh XLSX'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _unduh(context, xlsx: false),
                        icon: const Icon(Icons.description_outlined, size: 18),
                        label: const Text('Unduh CSV'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _tabel() {
    if (_memuat) {
      return const Padding(padding: EdgeInsets.all(18), child: SkeletonRow());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _muatKelas);
    }
    if (_rekap.isEmpty) {
      return const EmptyState(
        title: 'Belum ada data',
        message: 'Kelas ini belum memiliki siswa terdaftar.',
        icon: Icons.people_outline,
      );
    }
    // Header
    Widget header(String t) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(t,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary)),
        );
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      itemCount: _rekap.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                const Expanded(flex: 3, child: Text('Siswa',
                    style: TextStyle(fontWeight: FontWeight.w800,
                        fontSize: 12, color: AppColors.primary))),
                Expanded(flex: 1, child: header('H')),
                Expanded(flex: 1, child: header('T')),
                Expanded(flex: 1, child: header('I')),
                Expanded(flex: 1, child: header('S')),
                Expanded(flex: 1, child: header('A')),
              ],
            ),
          );
        }
        final r = _rekap[i - 1];
        Widget sel(int v, Color warna) => Text('$v',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: v == 0 ? AppColors.border : warna));
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.nama,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    if (r.nis.isNotEmpty)
                      Text('NIS ${r.nis}',
                          style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Expanded(flex: 1, child: sel(r.hadir, AppColors.success)),
              Expanded(flex: 1, child: sel(r.terlambat, AppColors.warning)),
              Expanded(flex: 1, child: sel(r.izin, AppColors.primary)),
              Expanded(flex: 1, child: sel(r.sakit, AppColors.purple)),
              Expanded(flex: 1, child: sel(r.alpa, AppColors.danger)),
            ],
          ),
        );
      },
    );
  }

  /// Unduh rekap sebagai XLSX atau CSV lalu buka share sheet.
  Future<void> _unduh(BuildContext context, {required bool xlsx}) async {
    try {
      showToast(context, 'Menyiapkan berkas…');
      final dir = await getTemporaryDirectory();
      final nama = xlsx
          ? 'rekap_presensi_${_periode.name}_${DateTime.now().millisecondsSinceEpoch}.xlsx'
          : 'rekap_presensi_${_periode.name}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${dir.path}/$nama');

      if (xlsx) {
        final excel = Excel.createExcel();
        final sheet = excel['Rekap'];
        sheet.appendRow([
          TextCellValue('Rekap Presensi $_judulPeriode'),
        ]);
        sheet.appendRow([
          TextCellValue('Kelas:'),
          TextCellValue(
              _kelas.firstWhere((k) => k['id'].toString() == _kelasId)['nama']
                      ?.toString() ??
                  '-'),
        ]);
        sheet.appendRow([]);
        sheet.appendRow([
          TextCellValue('NIS'),
          TextCellValue('Nama'),
          TextCellValue('Hadir'),
          TextCellValue('Terlambat'),
          TextCellValue('Izin'),
          TextCellValue('Sakit'),
          TextCellValue('Alpa'),
        ]);
        for (final r in _rekap) {
          sheet.appendRow([
            TextCellValue(r.nis),
            TextCellValue(r.nama),
            IntCellValue(r.hadir),
            IntCellValue(r.terlambat),
            IntCellValue(r.izin),
            IntCellValue(r.sakit),
            IntCellValue(r.alpa),
          ]);
        }
        final bytes = excel.encode();
        if (bytes == null) throw 'Gagal membuat XLSX';
        await file.writeAsBytes(bytes, flush: true);
      } else {
        final sb = StringBuffer('NIS,Nama,Hadir,Terlambat,Izin,Sakit,Alpa\n');
        for (final r in _rekap) {
          sb.write('${r.nis},"${r.nama}",${r.hadir},${r.terlambat},'
              '${r.izin},${r.sakit},${r.alpa}\n');
        }
        await file.writeAsString(sb.toString(), flush: true);
      }

      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)],
          subject: 'Rekap presensi $_judulPeriode');
    } catch (e) {
      if (mounted) {
        showToast(context, 'Gagal membuat berkas: $e', color: AppColors.danger);
      }
    }
  }
}

class _RekapBaris {
  const _RekapBaris({
    required this.uid,
    required this.nis,
    required this.nama,
    required this.hadir,
    required this.terlambat,
    required this.izin,
    required this.sakit,
    required this.alpa,
    required this.totalHari,
  });

  final String uid;
  final String nis;
  final String nama;
  final int hadir;
  final int terlambat;
  final int izin;
  final int sakit;
  final int alpa;
  final int totalHari;
}
