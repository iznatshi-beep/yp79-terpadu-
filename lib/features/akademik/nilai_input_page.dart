import 'package:flutter/material.dart';

import '../../../core/models/role.dart';
import '../../../core/models/session_profile.dart';
import '../../../core/theme.dart';
import '../../../services/repositories.dart';
import '../../../widgets/app_states.dart';
import '../../../widgets/common.dart';

/// Input nilai (guru & admin).
///
/// Menyambungkan `Repos.upsertGrade()` ke UI. Sebelumnya fungsi ini tidak
/// dipanggil layar mana pun sehingga guru tidak bisa memasukkan nilai.
class NilaiInputPage extends StatefulWidget {
  const NilaiInputPage({super.key, required this.profile});

  final SessionProfile profile;

  @override
  State<NilaiInputPage> createState() => _NilaiInputPageState();
}

class _NilaiInputPageState extends State<NilaiInputPage> {
  static const List<String> _kategori = [
    'tugas',
    'ujian',
    'harian',
    'prakarya',
    'karakter',
  ];
  static const List<String> _semester = ['gasal', 'genap'];

  bool _loading = true;
  String? _error;
  List<RowData> _kelas = const [];
  List<RowData> _mapel = const [];
  List<RowData> _siswa = const [];
  String? _kelasId;
  String? _mapelId;
  String _kategoriDipilih = 'tugas';
  String _semesterDipilih = 'gasal';
  final Map<String, TextEditingController> _nilai = {};
  bool _menyimpan = false;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    for (final c in _nilai.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final kelas = await Repos.classes();
    final mapel = await Repos.subjects();
    if (!mounted) return;

    var daftarKelas = kelas.data;
    if (widget.profile.role != Role.admin) {
      final asg = await Repos.teacherAssignments(teacherId: Repos.uid);
      if (!mounted) return;
      final idKelas = {
        for (final r in asg.data)
          if (r['class_id'] != null) r['class_id'].toString()
      };
      daftarKelas = daftarKelas
          .where((c) => idKelas.contains(c['id']?.toString()))
          .toList();
    }

    setState(() {
      _kelas = daftarKelas;
      _mapel = mapel.data;
      _loading = false;
      _error = kelas.ok ? (mapel.error) : kelas.error;
    });
  }

  Future<void> _muatSiswa() async {
    if (_kelasId == null) return;
    setState(() {
      _loading = true;
      _siswa = const [];
    });
    final siswa = await Repos.classStudents(_kelasId!);
    if (!mounted) return;
    for (final c in _nilai.values) {
      c.dispose();
    }
    _nilai.clear();
    setState(() {
      _siswa = siswa.data;
      _loading = false;
      _error = siswa.error;
    });
  }

  Future<void> _simpan() async {
    if (_kelasId == null || _mapelId == null) {
      showToast(context, 'Pilih kelas dan mata pelajaran dulu.',
          color: AppColors.warning);
      return;
    }

    final entri = <(String, double)>[];
    final tidakValid = <String>[];
    for (final s in _siswa) {
      final id = s['student_user_id']?.toString() ?? '';
      final teks = _nilai[id]?.text.trim() ?? '';
      if (id.isEmpty || teks.isEmpty) continue;
      final angka = double.tryParse(teks.replaceAll(',', '.'));
      if (angka == null || angka < 0 || angka > 100) {
        tidakValid.add(_namaSiswa(s));
        continue;
      }
      entri.add((id, angka));
    }

    if (tidakValid.isNotEmpty) {
      showToast(
        context,
        'Nilai tidak valid (harus 0-100): ${tidakValid.take(3).join(', ')}',
        color: AppColors.danger,
        durasi: 5,
      );
      return;
    }
    if (entri.isEmpty) {
      showToast(context, 'Belum ada nilai yang diisi.',
          color: AppColors.warning);
      return;
    }

    setState(() => _menyimpan = true);
    var sukses = 0;
    final gagal = <String>[];
    for (final (id, angka) in entri) {
      final ok = await Repos.upsertGrade(
        studentId: id,
        subjectId: _mapelId!,
        kategori: _kategoriDipilih,
        nilai: angka,
        semester: _semesterDipilih,
      );
      if (ok) {
        sukses++;
      } else {
        gagal.add(id);
      }
    }
    if (!mounted) return;
    setState(() => _menyimpan = false);

    if (gagal.isEmpty) {
      showToast(context, 'Nilai tersimpan: $sukses siswa.',
          color: AppColors.success);
    } else {
      showToast(
        context,
        'Tersimpan $sukses, gagal ${gagal.length}. '
        'Periksa penugasan mengajar Anda untuk mata pelajaran ini.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Input Nilai')),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Column(children: [SkeletonRow(), SkeletonRow()]),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _kelasId,
                        decoration: const InputDecoration(labelText: 'Kelas'),
                        items: [
                          for (final k in _kelas)
                            DropdownMenuItem(
                              value: k['id']?.toString(),
                              child: Text(k['nama']?.toString() ?? '-'),
                            ),
                        ],
                        onChanged: (v) {
                          setState(() => _kelasId = v);
                          _muatSiswa();
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _mapelId,
                        decoration:
                            const InputDecoration(labelText: 'Mata Pelajaran'),
                        items: [
                          for (final m in _mapel)
                            DropdownMenuItem(
                              value: m['id']?.toString(),
                              child: Text(m['nama']?.toString() ?? '-'),
                            ),
                        ],
                        onChanged: (v) => setState(() => _mapelId = v),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _kategoriDipilih,
                              decoration:
                                  const InputDecoration(labelText: 'Kategori'),
                              items: [
                                for (final k in _kategori)
                                  DropdownMenuItem(
                                      value: k, child: Text(k)),
                              ],
                              onChanged: (v) => setState(
                                  () => _kategoriDipilih = v ?? 'tugas'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _semesterDipilih,
                              decoration:
                                  const InputDecoration(labelText: 'Semester'),
                              items: [
                                for (final s in _semester)
                                  DropdownMenuItem(
                                      value: s, child: Text(s)),
                              ],
                              onChanged: (v) => setState(
                                  () => _semesterDipilih = v ?? 'gasal'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.danger),
                    ),
                  ),
                Expanded(child: _daftarSiswa()),
              ],
            ),
      bottomNavigationBar: _siswa.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
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
                  label: const Text('Simpan Nilai'),
                ),
              ),
            ),
    );
  }

  Widget _daftarSiswa() {
    if (_kelasId == null) {
      return const EmptyState(
        title: 'Pilih kelas',
        message: 'Pilih kelas dan mata pelajaran untuk mulai mengisi nilai.',
        icon: Icons.grade_outlined,
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
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      itemCount: _siswa.length,
      itemBuilder: (context, i) {
        final s = _siswa[i];
        final id = s['student_user_id']?.toString() ?? '';
        final ctrl = _nilai.putIfAbsent(id, TextEditingController.new);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _namaSiswa(s),
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 84,
                child: TextField(
                  controller: ctrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: '0-100',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
