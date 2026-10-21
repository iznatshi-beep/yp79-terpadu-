import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../services/repositories.dart';
import '../../widgets/app_states.dart';
import '../../widgets/common.dart';

/// Leger Nilai per kelas — gabungan otomatis:
/// - Tugas: rata-rata nilai assignment_submissions
/// - CBT: attempt terbaik, dinormalisasi ke skala 100
/// - Manual: nilai terbaru dari grading_records
/// Ekspor CSV sekali tap → share sheet (WhatsApp, dll).
class LegerNilaiPage extends StatefulWidget {
  const LegerNilaiPage({super.key});

  @override
  State<LegerNilaiPage> createState() => _LegerNilaiPageState();
}

class _LegerNilaiPageState extends State<LegerNilaiPage> {
  bool _memuat = true;
  String? _kelasId;
  String _kelasNama = '';
  List<RowData> _kelas = const [];
  List<Map<String, dynamic>> _data = const [];

  @override
  void initState() {
    super.initState();
    _muatKelas();
  }

  Future<void> _muatKelas() async {
    final res = await Repos.classes();
    if (!mounted) return;
    setState(() => _kelas = res.data);
    if (res.data.isNotEmpty && _kelasId == null) {
      _kelasId = res.data.first['id']?.toString();
      _kelasNama = res.data.first['nama']?.toString() ?? '';
      await _muatLeger();
    } else {
      setState(() => _memuat = false);
    }
  }

  Future<void> _muatLeger() async {
    if (_kelasId == null) return;
    setState(() => _memuat = true);
    final data = await Repos.legerKelas(classId: _kelasId!);
    if (!mounted) return;
    data.sort((a, b) =>
        (a['nama'] ?? '').toString().compareTo((b['nama'] ?? '').toString()));
    setState(() {
      _data = data;
      _memuat = false;
    });
  }

  void _pilihKelas(String? v) {
    setState(() {
      _kelasId = v;
      _kelasNama = _kelas
          .firstWhere((k) => k['id']?.toString() == v,
              orElse: () => const {})
          ['nama']
          ?.toString() ??
          '';
      _memuat = true;
    });
    _muatLeger();
  }

  String _n(dynamic v) => v is num ? v.toStringAsFixed(1) : '-';

  Future<void> _eksporCsv() async {
    if (_data.isEmpty) return;
    final buf = StringBuffer(
        'NIS,Nama,Rata-rata Tugas,Nilai CBT (skala 100),Nilai Manual\n');
    for (final r in _data) {
      String f(dynamic v) => v == null ? '' : (v as num).toStringAsFixed(1);
      final nama = '"${r['nama']}"';
      buf.writeln(
          '${r['nis']},$nama,${f(r['rata_tugas'])},${f(r['nilai_cbt'])},${f(r['nilai_manual'])}');
    }
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/leger_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buf.toString());
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)],
          text: 'Leger nilai — $_kelasNama');
    } catch (e) {
      if (mounted) {
        showToast(context, 'Gagal ekspor: $e', color: AppColors.danger);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Leger Nilai')),
      body: _isi(),
    );
  }

  Widget _isi() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _kelasId,
                  decoration:
                      const InputDecoration(labelText: 'Pilih kelas'),
                  items: [
                    for (final k in _kelas)
                      DropdownMenuItem(
                          value: k['id']?.toString(),
                          child: Text(k['nama']?.toString() ?? '-')),
                  ],
                  onChanged: _pilihKelas,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _data.isEmpty ? null : _eksporCsv,
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('CSV'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _memuat
              ? const Padding(
                  padding: EdgeInsets.all(18), child: SkeletonRow())
              : _data.isEmpty
                  ? const EmptyState(
                      title: 'Belum ada data',
                      message:
                          'Leger muncul otomatis setelah ada nilai tugas/CBT.',
                      icon: Icons.table_chart_outlined,
                    )
                  : _tabel(),
        ),
      ],
    );
  }

  Widget _tabel() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
      itemCount: _data.length,
      itemBuilder: (context, i) => _row(_data[i]),
    );
  }

  Widget _row(Map<String, dynamic> r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: appSoftShadow,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r['nama']?.toString() ?? '-',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: AppColors.ink)),
                Text('NIS ${r['nis'] ?? '-'}',
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Expanded(
            child: Text('Tugas ${_n(r['rata_tugas'])}',
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text('CBT ${_n(r['nilai_cbt'])}',
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text('Manual ${_n(r['nilai_manual'])}',
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
