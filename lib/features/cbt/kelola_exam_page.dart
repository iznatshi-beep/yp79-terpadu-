import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/repositories.dart';
import '../../widgets/app_states.dart';
import '../../widgets/common.dart';

/// Panel Kelola Ujian untuk guru/admin — dibuat biar sekolah non-tech
/// bisa bikin ujian tanpa sentuh database sama sekali:
///
/// 1. Daftar ujian → tap kartu: Aktifkan/Akhiri, Kelola Soal, Peserta.
/// 2. "+ Buat Ujian": judul, kelas, tanggal, durasi. Selesai.
/// 3. Editor soal: PG A–E (tap huruf yang benar) atau esai.
/// 4. Peserta: tap attempt → koreksi esai → nilai final = PG + esai.
class KelolaExamPage extends StatefulWidget {
  const KelolaExamPage({super.key});

  @override
  State<KelolaExamPage> createState() => _KelolaExamPageState();
}

class _KelolaExamPageState extends State<KelolaExamPage> {
  bool _memuat = true;
  List<RowData> _exams = const [];

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _memuat = true);
    final res = await Repos.exams();
    if (!mounted) return;
    setState(() {
      _exams = res.data;
      _memuat = false;
    });
  }

  Future<void> _bukaFormBuat() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _FormBuatExam(),
    );
    if (ok == true && mounted) _muat();
  }

  void _menuAksi(RowData e) {
    final status = e['status']?.toString() ?? 'draft';
    final id = e['id']?.toString() ?? '';
    final judul = e['judul']?.toString() ?? 'Ujian';
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('Pilih aksi',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            ListTile(
              leading: const Icon(Icons.quiz_outlined),
              title: const Text('Kelola Soal'),
              subtitle: const Text('Tambah PG A–E atau esai'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) =>
                        KelolaSoalPage(examId: id, judul: judul)));
              },
            ),
            if (status == 'draft')
              ListTile(
                leading: const Icon(Icons.play_circle_outline_rounded,
                    color: AppColors.success),
                title: const Text('AKTIFKAN UJIAN',
                    style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700)),
                subtitle:
                    const Text('Siswa langsung bisa mengerjakan'),
                onTap: () async {
                  Navigator.pop(context);
                  final err =
                      await Repos.ubahStatusExam(id, 'aktif');
                  if (!mounted) return;
                  showToast(context,
                      err ?? 'Ujian AKTIF — siswa bisa mengerjakan!',
                      color: err == null
                          ? AppColors.success
                          : AppColors.danger);
                  _muat();
                },
              ),
            if (status == 'aktif')
              ListTile(
                leading: const Icon(Icons.stop_circle_outlined),
                title: const Text('Akhiri ujian'),
                onTap: () async {
                  Navigator.pop(context);
                  final err =
                      await Repos.ubahStatusExam(id, 'selesai');
                  if (!mounted) return;
                  showToast(context,
                      err ?? 'Ujian diakhiri.',
                      color: err == null
                          ? AppColors.success
                          : AppColors.danger);
                  _muat();
                },
              ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Lihat peserta & koreksi esai'),
              onTap: () {
                Navigator.pop(context);
                _bukaPeserta(e);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _bukaPeserta(RowData e) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PesertaExamPage(
          examId: e['id']?.toString() ?? '',
          judul: e['judul']?.toString() ?? 'Ujian',
        ),
      ),
    );
  }

  String _tanggal(dynamic t) =>
      (t?.toString() ?? '').split('T').first;

  String _statusLabel(String s) => switch (s) {
        'draft' => 'DRAF',
        'aktif' => 'AKTIF',
        'selesai' => 'SELESAI',
        _ => s.toUpperCase(),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Kelola Ujian')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _bukaFormBuat,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Buat Ujian'),
      ),
      body: _isi(),
    );
  }

  Widget _isi() {
    if (_memuat) {
      return const Padding(padding: EdgeInsets.all(18), child: SkeletonRow());
    }
    if (_exams.isEmpty) {
      return EmptyState(
        title: 'Belum ada ujian',
        message: 'Tekan "Buat Ujian" — semuanya bisa dari sini, tanpa setup lain.',
        icon: Icons.edit_note_rounded,
      );
    }
    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 90),
        itemCount: _exams.length,
        itemBuilder: (context, i) => _kartu(_exams[i]),
      ),
    );
  }

  Widget _kartu(RowData e) {
    final status = e['status']?.toString() ?? 'draft';
    final (badgeState, badgeLabel) = switch (status) {
      'aktif' => (BadgeState.success, 'AKTIF'),
      'selesai' => (BadgeState.neutral, 'SELESAI'),
      _ => (BadgeState.warning, 'DRAF'),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: appSoftShadow,
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(e['judul']?.toString() ?? '-',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.ink)),
          subtitle: Text(
            'Mulai ${_tanggal(e['mulai'])} · Selesai ${_tanggal(e['selesai'])} · '
            '${e['durasi_menit'] ?? 60} mnt',
            style:
                const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
          trailing: StatusBadge(label: badgeLabel, state: badgeState),
          onTap: () => _menuAksi(e),
        ),
      ),
    );
  }
}

/// Form buat ujian — sesimpel mungkin: judul, kelas, tanggal, durasi.
class _FormBuatExam extends StatefulWidget {
  const _FormBuatExam();

  @override
  State<_FormBuatExam> createState() => _FormBuatExamState();
}

class _FormBuatExamState extends State<_FormBuatExam> {
  final _judul = TextEditingController();
  final _durasi = TextEditingController(text: '60');
  String? _kelasId;
  DateTime _mulai = DateTime.now();
  DateTime _selesai = DateTime.now().add(const Duration(days: 1));
  List<RowData> _kelas = const [];
  bool _sibuk = false;

  @override
  void initState() {
    super.initState();
    _muatKelas();
  }

  @override
  void dispose() {
    _judul.dispose();
    _durasi.dispose();
    super.dispose();
  }

  Future<void> _muatKelas() async {
    final res = await Repos.classes();
    if (!mounted) return;
    setState(() => _kelas = res.data);
  }

  Future<void> _pilihTanggal({required bool mulai}) async {
    final t = await showDatePicker(
      context: context,
      initialDate: mulai ? _mulai : _selesai,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (t == null) return;
    setState(() => mulai ? (_mulai = t) : (_selesai = t));
  }

  Future<void> _simpan() async {
    if (_judul.text.trim().isEmpty || _kelasId == null) {
      showToast(context, 'Judul dan kelas wajib diisi.',
          color: AppColors.warning);
      return;
    }
    setState(() => _sibuk = true);
    final r = await Repos.buatExam(
      judul: _judul.text.trim(),
      classId: _kelasId,
      mulai: DateTime(_mulai.year, _mulai.month, _mulai.day, 0, 0),
      selesai: DateTime(_selesai.year, _selesai.month, _selesai.day, 23, 59),
      durasiMenit: int.tryParse(_durasi.text.trim()) ?? 60,
    );
    if (!mounted) return;
    if (r.error != null) {
      showToast(context, r.error!, color: AppColors.danger);
      setState(() => _sibuk = false);
      return;
    }
    Navigator.pop(context, true);
  }

  String _fmtTgl(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 18, right: 18, top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Buat Ujian Baru',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(
              controller: _judul,
              decoration: const InputDecoration(
                  labelText: 'Judul ujian',
                  hintText: 'mis. UAS Matematika Semester 1'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _kelasId,
              decoration: const InputDecoration(labelText: 'Kelas'),
              items: [
                for (final k in _kelas)
                  DropdownMenuItem(
                      value: k['id']?.toString(),
                      child: Text(k['nama']?.toString() ?? '-')),
              ],
              onChanged: (v) => setState(() => _kelasId = v),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pilihTanggal(mulai: true),
                  icon: const Icon(Icons.event_outlined, size: 16),
                  label: Text('Mulai: ${_fmtTgl(_mulai)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pilihTanggal(mulai: false),
                  icon: const Icon(Icons.event_available_outlined, size: 16),
                  label: Text('Selesai: ${_fmtTgl(_selesai)}'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _durasi,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Durasi (menit)'),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _sibuk ? null : _simpan,
              icon: _sibuk
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded),
              label: const Text('Simpan Ujian (DRAF)'),
            ),
            const SizedBox(height: 6),
            const Text(
              'Setelah disimpan: tambah soal → tekan "AKTIFKAN UJIAN".',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kelola soal satu ujian: daftar + tambah (PG A-E / esai) + hapus.
class KelolaSoalPage extends StatefulWidget {
  const KelolaSoalPage({super.key, required this.examId, required this.judul});

  final String examId;
  final String judul;

  @override
  State<KelolaSoalPage> createState() => _KelolaSoalPageState();
}

class _KelolaSoalPageState extends State<KelolaSoalPage> {
  List<Map<String, dynamic>> _soal = const [];
  bool _memuat = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _memuat = true);
    final res = await Repos.examQuestionsWithKey(widget.examId);
    if (!mounted) return;
    setState(() {
      _soal = res.data;
      _memuat = false;
    });
  }

  Future<void> _tambahSoal() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormSoal(examId: widget.examId),
    );
    if (ok == true && mounted) _muat();
  }

  Future<void> _hapusSoal(String qid) async {
    final ok = await showConfirmDialog(
      context,
      judul: 'Hapus soal?',
      pesan: 'Soal ini akan dihapus dari ujian.',
      tombolYa: 'Hapus',
    );
    if (!ok) return;
    final err = await Repos.hapusSoal(qid);
    if (!mounted) return;
    showToast(context, err ?? 'Soal dihapus.',
        color: err == null ? AppColors.success : AppColors.danger);
    _muat();
  }

  String _pendek(dynamic t) {
    final s = t?.toString() ?? '';
    return s.length > 22 ? '${s.substring(0, 20)}…' : s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Soal — ${widget.judul}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tambahSoal,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Soal'),
      ),
      body: _isi(),
    );
  }

  Widget _isi() {
    if (_memuat) {
      return const Padding(padding: EdgeInsets.all(18), child: SkeletonRow());
    }
    if (_soal.isEmpty) {
      return EmptyState(
        title: 'Belum ada soal',
        message: 'Tambah soal pilihan ganda (A–E) atau esai. '
            'Titik radio di kiri = KUNCI JAWABAN.',
        icon: Icons.help_outline_rounded,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 90),
      itemCount: _soal.length,
      itemBuilder: (context, i) {
        final q = _soal[i];
        final tipe = q['tipe']?.toString() ?? 'pilihan';
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusBadge(
                        label: tipe == 'esai' ? 'ESAI' : 'PG',
                        state: BadgeState.info),
                    const Spacer(),
                    Text('${q['skor'] ?? 1} poin',
                        style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 20, color: AppColors.danger),
                      onPressed: () =>
                          _hapusSoal(q['id']?.toString() ?? ''),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${i + 1}. ${q['pertanyaan']?.toString() ?? ''}',
                    style: const TextStyle(
                        fontSize: 13.5, color: AppColors.ink)),
                if (tipe != 'esai') ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final l in ['a', 'b', 'c', 'd', 'e'])
                        if (q['opsi_$l'] != null)
                          Chip(
                            label: Text(
                                '${l.toUpperCase()}. ${_pendek(q['opsi_$l'])}'),
                            avatar: (q['kunci']?.toString().toLowerCase() == l)
                                ? const Icon(Icons.check_circle,
                                    size: 16, color: AppColors.success)
                                : null,
                          ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Form tambah soal: PG A–E (pilih kunci lewat radio) atau esai.
class _FormSoal extends StatefulWidget {
  const _FormSoal({required this.examId});
  final String examId;

  @override
  State<_FormSoal> createState() => _FormSoalState();
}

class _FormSoalState extends State<_FormSoal> {
  final _pertanyaan = TextEditingController();
  final _opsi = {
    for (final l in ['a', 'b', 'c', 'd', 'e']) l: TextEditingController(),
  };
  String _kunci = 'a';
  String _tipe = 'pilihan';
  bool _sibuk = false;

  @override
  void dispose() {
    _pertanyaan.dispose();
    for (final c in _opsi.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _simpan() async {
    if (_pertanyaan.text.trim().isEmpty) {
      showToast(context, 'Pertanyaan wajib diisi.', color: AppColors.warning);
      return;
    }
    setState(() => _sibuk = true);
    final String? err;
    if (_tipe == 'esai') {
      err = await Repos.tambahSoalEsai(
          examId: widget.examId, pertanyaan: _pertanyaan.text.trim());
    } else {
      err = await Repos.tambahSoalPG(
        examId: widget.examId,
        pertanyaan: _pertanyaan.text.trim(),
        opsiA: _opsi['a']!.text.trim(),
        opsiB: _opsi['b']!.text.trim(),
        opsiC: _opsi['c']!.text.trim().isEmpty ? null : _opsi['c']!.text.trim(),
        opsiD: _opsi['d']!.text.trim().isEmpty ? null : _opsi['d']!.text.trim(),
        opsiE: _opsi['e']!.text.trim().isEmpty ? null : _opsi['e']!.text.trim(),
        kunci: _kunci,
      );
    }
    if (!mounted) return;
    if (err != null) {
      showToast(context, err, color: AppColors.danger);
      setState(() => _sibuk = false);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 18, right: 18, top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'pilihan', label: Text('Pilihan Ganda')),
                ButtonSegment(value: 'esai', label: Text('Esai')),
              ],
              selected: {_tipe},
              onSelectionChanged: (v) => setState(() => _tipe = v.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pertanyaan,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Pertanyaan'),
            ),
            const SizedBox(height: 12),
            if (_tipe == 'esai')
              const Text(
                'Esai dinilai manual oleh guru setelah ujian (tab Peserta).',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              )
            else ...[
              const Text(
                'Titik bulat di kiri = KUNCI JAWABAN (jawaban benar).',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              for (final l in ['a', 'b', 'c', 'd', 'e'])
                Row(
                  children: [
                    Radio<String>(
                      value: l,
                      groupValue: _kunci,
                      onChanged: (v) => setState(() => _kunci = v ?? 'a'),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _opsi[l],
                        decoration: InputDecoration(
                            labelText:
                                'Opsi ${l.toUpperCase()}${l == 'e' ? ' (opsional)' : ''}'),
                      ),
                    ),
                  ],
                ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _sibuk ? null : _simpan,
              icon: _sibuk
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded),
              label: const Text('Simpan Soal'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Peserta satu ujian + pintu ke koreksi esai.
class PesertaExamPage extends StatefulWidget {
  const PesertaExamPage(
      {super.key, required this.examId, required this.judul});

  final String examId;
  final String judul;

  @override
  State<PesertaExamPage> createState() => _PesertaExamPageState();
}

class _PesertaExamPageState extends State<PesertaExamPage> {
  bool _memuat = true;
  List<Map<String, dynamic>> _peserta = const [];

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final data = await Repos.examPeserta(widget.examId);
    if (!mounted) return;
    setState(() {
      _peserta = data;
      _memuat = false;
    });
  }

  void _bukaKoreksi(Map<String, dynamic> p) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KoreksiEsaiPage(
          attemptId: p['id']?.toString() ?? '',
          nama: p['nama']?.toString() ?? '-',
          nis: p['nis']?.toString() ?? '-',
        ),
      ),
    ).then((_) => _muat());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Peserta — ${widget.judul}')),
      body: _isi(),
    );
  }

  Widget _isi() {
    if (_memuat) {
      return const Padding(padding: EdgeInsets.all(18), child: SkeletonRow());
    }
    if (_peserta.isEmpty) {
      return const EmptyState(
        title: 'Belum ada peserta',
        message: 'Peserta muncul otomatis begitu siswa mulai mengerjakan.',
        icon: Icons.people_outline_rounded,
      );
    }
    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: _peserta.length,
        itemBuilder: (context, i) {
          final p = _peserta[i];
          final status = p['status']?.toString() ?? '-';
          final pg = p['nilai_pilihan'];
          final esai = p['nilai_esai'];
          final pel = p['pelanggaran'] ?? 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(p['nama']?.toString() ?? '-',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: Text(
                'NIS ${p['nis'] ?? '-'} · $status'
                '${pg != null ? ' · PG: $pg' : ''}'
                '${esai != null && (esai as num) > 0 ? ' · Esai: $esai' : ''}'
                '${(pel as num) > 0 ? ' · Pelanggaran: $pel' : ''}',
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _bukaKoreksi(p),
            ),
          );
        },
      ),
    );
  }
}

/// Koreksi esai satu attempt: input nilai per soal, total = PG + esai.
class KoreksiEsaiPage extends StatefulWidget {
  const KoreksiEsaiPage({
    super.key,
    required this.attemptId,
    required this.nama,
    required this.nis,
  });

  final String attemptId;
  final String nama;
  final String nis;

  @override
  State<KoreksiEsaiPage> createState() => _KoreksiEsaiPageState();
}

class _KoreksiEsaiPageState extends State<KoreksiEsaiPage> {
  List<Map<String, dynamic>> _soal = const [];
  bool _memuat = true;
  final Map<String, TextEditingController> _ctrl = {};

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _muat() async {
    final data = await Repos.examEsaiJawaban(widget.attemptId);
    if (!mounted) return;
    setState(() {
      _soal = data;
      for (final s in data) {
        final qid = s['question_id']?.toString() ?? '';
        _ctrl[qid] = TextEditingController(
            text: s['nilai_esai']?.toString() ?? '');
      }
      _memuat = false;
    });
  }

  Future<void> _simpan(String questionId, double nilai) async {
    final total = await Repos.simpanNilaiEsai(
        widget.attemptId, questionId, nilai);
    if (!mounted) return;
    showToast(
      context,
      total != null ? 'Nilai esai tersimpan. Total: $total' : 'Gagal simpan.',
      color: total != null ? AppColors.success : AppColors.danger,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Koreksi — ${widget.nama}')),
      body: _isi(),
    );
  }

  Widget _isi() {
    if (_memuat) {
      return const Padding(padding: EdgeInsets.all(18), child: SkeletonRow());
    }
    if (_soal.isEmpty) {
      return const EmptyState(
        title: 'Tidak ada soal esai',
        message: 'Ujian ini tidak punya soal esai — nilai PG otomatis.',
        icon: Icons.task_alt_rounded,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text('NIS: ${widget.nis}',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        for (final s in _soal)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Soal ${s['urutan']} · maks ${s['skor']} poin',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(s['pertanyaan']?.toString() ?? '',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      (s['jawaban']?.toString() ?? '').isEmpty
                          ? '(tidak menjawab)'
                          : s['jawaban']?.toString() ?? '-',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ctrl[s['question_id']?.toString()],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Nilai esai (0..maks)',
                              isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          final v = double.tryParse(
                              _ctrl[s['question_id']?.toString()]?.text ?? '');
                          if (v == null) {
                            showToast(context, 'Isi angka dulu.',
                                color: AppColors.warning);
                            return;
                          }
                          _simpan(
                              s['question_id']?.toString() ?? '', v);
                        },
                        child: const Text('Simpan'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
