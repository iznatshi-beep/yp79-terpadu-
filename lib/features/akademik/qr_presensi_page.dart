import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme.dart';
import '../../../services/repositories.dart';
import '../../../widgets/common.dart';

/// Halaman QR presensi: guru/admin memilih siswa yang belum hadir,
/// menghasilkan token presensi dari server (`generate_attendance_qr`) lalu
/// menampilkannya sebagai QR. Token diverifikasi `verify_attendance_qr`
/// di server dan presensinya tercatat.
class QrPresensiPage extends StatefulWidget {
  const QrPresensiPage({super.key, required this.siswa});

  /// Daftar siswa: {'user_id': ..., 'nama': ...}
  final List<Map<String, dynamic>> siswa;

  @override
  State<QrPresensiPage> createState() => _QrPresensiPageState();
}

class _QrPresensiPageState extends State<QrPresensiPage> {
  String? _uid;
  String? _nama;
  String? _nis;
  String? _token;
  bool _sibuk = false;
  String? _error;
  String _cari = '';

  List<Map<String, dynamic>> get _terfilter {
    final q = _cari.trim().toLowerCase();
    if (q.isEmpty) return widget.siswa;
    return [
      for (final s in widget.siswa)
        if ((s['nama']?.toString().toLowerCase().contains(q) ?? false) ||
            (s['nis']?.toString().toLowerCase().contains(q) ?? false))
          s
    ];
  }

  Future<void> _generate(String userId, String nama, String nis) async {
    setState(() {
      _sibuk = true;
      _error = null;
    });
    final token = await Repos.generateAttendanceQr(userId);
    if (!mounted) return;
    if (token == null) {
      setState(() {
        _sibuk = false;
        _error = 'Gagal membuat token. Coba lagi.';
      });
      return;
    }
    setState(() {
      _uid = userId;
      _nama = nama;
      _nis = nis;
      _token = token;
      _sibuk = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('QR Presensi')),
      body: _token == null ? _pilihSiswa() : _tampilQr(),
    );
  }

  Widget _pilihSiswa() {
    if (widget.siswa.isEmpty) {
      return const Center(
        child: Text('Semua siswa sudah presensi hari ini.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: TextField(
            onChanged: (v) => setState(() => _cari = v),
            decoration: const InputDecoration(
              hintText: 'Cari NIS atau nama siswa',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            itemCount: _terfilter.length,
            itemBuilder: (context, i) {
              final s = _terfilter[i];
              final uid = s['user_id']?.toString() ??
                  s['student_user_id']?.toString() ??
                  '';
              final nis = s['nis']?.toString() ?? '';
              return ListTile(
                leading: Text(nis.isEmpty ? '—' : nis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.primary)),
                title: Text(s['nama']?.toString() ?? '-'),
                subtitle: const Text('Ketuk untuk buat QR presensi',
                    style: TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary)),
                onTap: _sibuk
                    ? null
                    : () =>
                        _generate(uid, s['nama']?.toString() ?? '-', nis),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _tampilQr() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Presensi QR — $_nama',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            if (_nis?.isNotEmpty ?? false)
              Text('NIS $_nis',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: QrImageView(
                data: _token!,
                size: 240,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            const Text('Minta siswa memindai QR ini dari aplikasinya.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            const Text('Token berlaku hari ini, satu kali presensi.',
                style: TextStyle(
                    fontSize: 11.5, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed:
                  _sibuk ? null : () => _generate(_uid!, _nama ?? '', _nis ?? ''),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Buat ulang token'),
            ),
          ],
        ),
      ),
    );
  }
}
