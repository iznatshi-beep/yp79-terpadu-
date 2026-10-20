import 'package:flutter/material.dart';

import '../../../core/models/role.dart';
import '../../../core/models/session_profile.dart';
import '../../../core/theme.dart';
import '../../../services/repositories.dart';
import '../../../widgets/app_states.dart';
import '../../../widgets/common.dart';
import 'qr_presensi_page.dart';

/// Input presensi kelas (guru & admin).
///
/// Menyambungkan `Repos.upsertAttendance()` ke UI — sebelumnya jalur tulis ini
/// tidak pernah dipanggil layar mana pun, sehingga guru tidak bisa mengisi
/// presensi sama sekali.
class PresensiInputPage extends StatefulWidget {
  const PresensiInputPage({super.key, required this.profile});

  final SessionProfile profile;

  @override
  State<PresensiInputPage> createState() => _PresensiInputPageState();
}

class _PresensiInputPageState extends State<PresensiInputPage> {
  static const List<({String kode, String label, Color warna})> _status = [
    (kode: 'hadir', label: 'Hadir', warna: AppColors.success),
    (kode: 'terlambat', label: 'Terlambat', warna: AppColors.warning),
    (kode: 'izin', label: 'Izin', warna: AppColors.primary),
    (kode: 'sakit', label: 'Sakit', warna: AppColors.purple),
    (kode: 'alpa', label: 'Alpa', warna: AppColors.danger),
  ];

  bool _loading = true;
  String? _error;
  String? _pesan;
  List<RowData> _kelas = const [];
  RowData? _kelasDipilih;
  List<RowData> _siswa = const [];
  final Map<String, String> _statusTerpilih = {};
  DateTime _tanggal = DateTime.now();
  bool _menyimpan = false;

  @override
  void initState() {
    super.initState();
    _muatKelas();
  }

  String get _tanggalStr =>
      '${_tanggal.year}-${_tanggal.month.toString().padLeft(2, '0')}-${_tanggal.day.toString().padLeft(2, '0')}';

  Future<void> _muatKelas() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final semua = await Repos.classes();
    if (!mounted) return;
    if (!semua.ok) {
      setState(() {
        _loading = false;
        _error = semua.error;
      });
      return;
    }

    var daftar = semua.data;
    if (widget.profile.role != Role.admin) {
      // Guru hanya melihat kelas yang diampu (sesuai batasan RLS).
      final asg = await Repos.teacherAssignments(teacherId: Repos.uid);
      final idKelas = {
        for (final r in asg.data)
          if (r['class_id'] != null) r['class_id'].toString()
      };
      daftar = daftar
          .where((c) => idKelas.contains(c['id']?.toString()))
          .toList();
    }

    setState(() {
      _kelas = daftar;
      _loading = false;
      _pesan = daftar.isEmpty
          ? 'Anda belum ditugaskan pada kelas mana pun. Hubungi admin.'
          : null;
    });
  }

  Future<void> _pilihKelas(RowData kelas) async {
    setState(() {
      _kelasDipilih = kelas;
      _loading = true;
      _siswa = const [];
      _statusTerpilih.clear();
    });

    final siswa = await Repos.classStudents(kelas['id'].toString());
    if (!mounted) return;

    // Ambil presensi tanggal terpilih supaya input bukan menimpa tanpa sadar.
    final existing = await Repos.attendance(
      classId: kelas['id'].toString(),
      mulai: _tanggal,
      sampai: _tanggal,
    );
    if (!mounted) return;

    final mapExisting = <String, String>{
      for (final r in existing.data)
        if (r['student_user_id'] != null)
          r['student_user_id'].toString(): (r['status'] ?? 'hadir').toString()
    };

    setState(() {
      _siswa = siswa.data;
      for (final s in _siswa) {
        final id = s['student_user_id']?.toString() ?? '';
        _statusTerpilih[id] = mapExisting[id] ?? 'hadir';
      }
      _loading = false;
    });
  }

  Future<void> _pilihTanggal() async {
    final t = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (t == null || !mounted) return;
    setState(() => _tanggal = t);
    if (_kelasDipilih != null) await _pilihKelas(_kelasDipilih!);
  }

  Future<void> _simpan() async {
    if (_kelasDipilih == null || _siswa.isEmpty) return;
    final ok = await showConfirmDialog(
      context,
      judul: 'Simpan presensi?',
      pesan:
          'Menyimpan presensi ${_siswa.length} siswa untuk tanggal $_tanggalStr.',
      tombolYa: 'Simpan',
    );
    if (!ok) return;

    setState(() => _menyimpan = true);
    var sukses = 0;
    final gagal = <String>[];
    for (final s in _siswa) {
      final id = s['student_user_id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final berhasil = await Repos.upsertAttendance(
        studentId: id,
        tanggal: _tanggalStr,
        status: _statusTerpilih[id] ?? 'hadir',
        metode: 'manual',
      );
      if (berhasil) {
        sukses++;
      } else {
        gagal.add(_namaSiswa(s));
      }
    }
    if (!mounted) return;
    setState(() => _menyimpan = false);

    if (gagal.isEmpty) {
      showToast(context, 'Presensi tersimpan: $sukses siswa.',
          color: AppColors.success);
    } else {
      showToast(
        context,
        'Tersimpan $sukses, GAGAL ${gagal.length}: ${gagal.take(3).join(', ')}'
        '${gagal.length > 3 ? '...' : ''}',
        color: AppColors.danger,
        durasi: 6,
      );
    }
  }

  String _namaSiswa(RowData s) {
    final p = s['student_profiles'];
    if (p is Map && p['nama_lengkap'] != null) {
      return p['nama_lengkap'].toString();
    }
    return s['student_user_id']?.toString() ?? '-';
  }

  String _nisSiswa(RowData s) {
    final p = s['student_profiles'];
    if (p is Map && p['nis'] != null) return p['nis'].toString();
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Presensi'),
        actions: [
          IconButton(
            tooltip: 'Pilih tanggal',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: _pilihTanggal,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Tanggal: $_tanggalStr',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                ),
                if (_kelasDipilih != null)
                  Text(
                    '${_siswa.length} siswa',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          if (_pesan != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                _pesan!,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.warning),
              ),
            ),
          if (_kelas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: DropdownButtonFormField<String>(
                initialValue: _kelasDipilih?['id']?.toString(),
                decoration: const InputDecoration(labelText: 'Kelas'),
                items: [
                  for (final k in _kelas)
                    DropdownMenuItem(
                      value: k['id']?.toString(),
                      child: Text(k['nama']?.toString() ?? '-'),
                    ),
                ],
                onChanged: (v) {
                  final k = _kelas.firstWhere(
                    (e) => e['id']?.toString() == v,
                    orElse: () => const <String, dynamic>{},
                  );
                  if (k.isNotEmpty) _pilihKelas(k);
                },
              ),
            ),
          Expanded(child: _body()),
        ],
      ),
      bottomNavigationBar: _siswa.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _menyimpan ? null : _simpan,
                        icon: _menyimpan
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save_outlined, size: 18),
                        label: Text('Simpan (${_siswa.length} siswa)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QrPresensiPage(
                              siswa: [
                                for (final s in _siswa)
                                  {
                                    'user_id':
                                        s['student_user_id']?.toString() ?? '',
                                    'nama': _namaSiswa(s),
                                  },
                              ],
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                      label: const Text('QR'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Column(children: [SkeletonRow(), SkeletonRow()]),
      );
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _muatKelas);
    }
    if (_kelasDipilih == null) {
      return const EmptyState(
        title: 'Pilih kelas',
        message: 'Pilih kelas di atas untuk mulai mengisi presensi.',
        icon: Icons.fact_check_outlined,
      );
    }
    if (_siswa.isEmpty) {
      return const EmptyState(
        title: 'Belum ada siswa',
        message: 'Kelas ini belum memiliki siswa terdaftar.',
        icon: Icons.people_outline,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      itemCount: _siswa.length,
      itemBuilder: (context, i) {
        final s = _siswa[i];
        final id = s['student_user_id']?.toString() ?? '';
        final dipilih = _statusTerpilih[id] ?? 'hadir';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: appSoftShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _namaSiswa(s),
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _nisSiswa(s),
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final st in _status)
                    ChoiceChip(
                      label: Text(st.label,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: dipilih == st.kode
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          )),
                      selected: dipilih == st.kode,
                      selectedColor: st.warna,
                      onSelected: (_) =>
                          setState(() => _statusTerpilih[id] = st.kode),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
