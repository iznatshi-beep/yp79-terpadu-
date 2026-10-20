import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/repositories.dart';
import '../../widgets/app_states.dart';
import '../../widgets/common.dart';

/// Master data (admin): kelola Kelas, Mapel, dan Jadwal.
/// Tulis langsung ke tabel; RLS server hanya mengizinkan admin.
class MasterDataPage extends StatefulWidget {
  const MasterDataPage({super.key});

  @override
  State<MasterDataPage> createState() => _MasterDataPageState();
}

class _MasterDataPageState extends State<MasterDataPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Data Master Akademik'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [Tab(text: 'Kelas'), Tab(text: 'Mapel'), Tab(text: 'Jadwal')],
          ),
        ),
        body: const TabBarView(
          children: [_KelasTab(), _MapelTab(), _JadwalTab()],
        ),
      ),
    );
  }
}

Future<bool> _hapus(BuildContext context, String tabel, String id, String nama,
    VoidCallback refresh) async {
  final yakin = await showConfirmDialog(
    context,
    judul: 'Hapus $nama?',
    pesan: 'Data yang sudah dipakai modul lain bisa gagal dihapus.',
    tombolYa: 'Hapus',
    warnColor: AppColors.danger,
  );
  if (!yakin) return false;
  try {
    await Repos.db.from(tabel).delete().eq('id', id);
    if (context.mounted) {
      showToast(context, 'Terhapus.', color: AppColors.success);
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      showToast(context, 'Gagal: $e', color: AppColors.danger);
    }
    return false;
  }
}

Future<void> _pesanError(BuildContext context, Object e) async {
  if (context.mounted) {
    showToast(context, 'Gagal: $e', color: AppColors.danger);
  }
}

// ---------------------------------------------------------------------------
// KELAS
// ---------------------------------------------------------------------------
class _KelasTab extends StatelessWidget {
  const _KelasTab();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QueryResult<RowData>>(
      future: Repos.classes(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(16), child: SkeletonRow());
        }
        final rows = snap.data?.data ?? const <RowData>[];
        return Stack(
          children: [
            if (rows.isEmpty)
              const EmptyState(
                title: 'Belum ada kelas',
                message: 'Tekan tombol tambah di kanan bawah.',
                icon: Icons.class_outlined,
              )
            else
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 90),
                itemCount: rows.length,
                itemBuilder: (context, i) => _barisKelas(context, rows[i]),
              ),
            Positioned(
              right: 18,
              bottom: 18,
              child: FloatingActionButton.extended(
                onPressed: () => _tambahKelas(context),
                icon: const Icon(Icons.add),
                label: const Text('Kelas'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _barisKelas(BuildContext context, RowData k) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: appSoftShadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(k['nama']?.toString() ?? '-',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink)),
                  Text('${k['jenjang'] ?? '-'} · ${k['tahun_ajaran'] ?? '-'}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.danger, size: 20),
              tooltip: 'Hapus kelas',
              onPressed: () => _hapus(context, 'classes', k['id'].toString(),
                  k['nama']?.toString() ?? 'kelas'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _tambahKelas(BuildContext context) async {
  final namaCtrl = TextEditingController();
  final jenjangCtrl = TextEditingController(text: 'VII');
  final tahunCtrl = TextEditingController(text: '2026/2027');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Tambah kelas'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: namaCtrl,
              decoration:
                  const InputDecoration(labelText: 'Nama kelas (mis. 7A)')),
          const SizedBox(height: 10),
          TextField(
              controller: jenjangCtrl,
              decoration:
                  const InputDecoration(labelText: 'Jenjang (VII/VIII/IX)')),
          const SizedBox(height: 10),
          TextField(
              controller: tahunCtrl,
              decoration: const InputDecoration(
                  labelText: 'Tahun ajaran (2026/2027)')),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan')),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await Repos.db.from('classes').insert({
      'nama': namaCtrl.text.trim(),
      'jenjang': jenjangCtrl.text.trim(),
      'tahun_ajaran': tahunCtrl.text.trim(),
    });
    if (context.mounted) {
      showToast(context, 'Kelas ditambahkan.', color: AppColors.success);
    }
  } catch (e) {
    if (context.mounted) _pesanError(context, e);
  }
}

Future<void> _tambahMapel(BuildContext context) async {
  final kodeCtrl = TextEditingController();
  final namaCtrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Tambah mapel'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: namaCtrl,
              decoration:
                  const InputDecoration(labelText: 'Nama mapel (mis. Matematika)')),
          const SizedBox(height: 10),
          TextField(
              controller: kodeCtrl,
              decoration:
                  const InputDecoration(labelText: 'Kode (mis. MAT7)')),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan')),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await Repos.db.from('subjects').insert({
      'kode': kodeCtrl.text.trim(),
      'nama': namaCtrl.text.trim(),
    });
    if (context.mounted) {
      showToast(context, 'Mapel ditambahkan.', color: AppColors.success);
    }
  } catch (e) {
    if (context.mounted) _pesanError(context, e);
  }
}

// ---------------------------------------------------------------------------
// MAPEL
// ---------------------------------------------------------------------------
class _MapelTab extends StatelessWidget {
  const _MapelTab();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QueryResult<RowData>>(
      future: Repos.subjects(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(16), child: SkeletonRow());
        }
        if (snap.data?.error != null) {
          return ErrorState(message: snap.data!.error!, onRetry: () {});
        }
        final rows = snap.data?.data ?? const <RowData>[];
        return Stack(
          children: [
            if (rows.isEmpty)
              const EmptyState(
                title: 'Belum ada mapel',
                message: 'Tekan tombol tambah untuk menambah mata pelajaran.',
                icon: Icons.menu_book_outlined,
              )
            else
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 90),
                itemCount: rows.length,
                itemBuilder: (context, i) => _barisMapel(context, rows[i]),
              ),
            Positioned(
              right: 18,
              bottom: 18,
              child: FloatingActionButton.extended(
                onPressed: () => _tambahMapel(context),
                icon: const Icon(Icons.add),
                label: const Text('Mapel'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _barisMapel(BuildContext context, RowData m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: appSoftShadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                  '${m['kode']?.toString() ?? '-'} — ${m['nama']?.toString() ?? '-'}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.danger, size: 20),
              tooltip: 'Hapus mapel',
              onPressed: () => _hapus(context, 'subjects', m['id'].toString(),
                  m['nama']?.toString() ?? 'mapel'),
            ),
          ],
        ),
      ),
    );
  }
}
// JADWAL
// ---------------------------------------------------------------------------
class _JadwalTab extends StatelessWidget {
  const _JadwalTab();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QueryResult<RowData>>(
      future: Repos.schedules(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(16), child: SkeletonRow());
        }
        final rows = snap.data?.data ?? const <RowData>[];
        return Stack(
          children: [
            if (rows.isEmpty)
              const EmptyState(
                title: 'Belum ada jadwal',
                message: 'Tambahkan jadwal mengajar per kelas.',
                icon: Icons.schedule_outlined,
              )
            else
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 90),
                itemCount: rows.length,
                itemBuilder: (context, i) => _barisJadwal(context, rows[i]),
              ),
            Positioned(
              right: 18,
              bottom: 18,
              child: FloatingActionButton.extended(
                onPressed: () => _tambahJadwal(context),
                icon: const Icon(Icons.add),
                label: const Text('Jadwal'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _barisJadwal(BuildContext context, RowData j) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: appSoftShadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${j['hari'] ?? '-'} · jam ${j['jam_ke'] ?? '-'} (${j['jam_mulai'] ?? '-'} - ${j['jam_selesai'] ?? '-'})',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink)),
                  Text('Ruang: ${j['ruang'] ?? '-'}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.danger, size: 20),
              tooltip: 'Hapus jadwal',
              onPressed: () => _hapus(context, 'schedules', j['id'].toString(),
                  'jadwal'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _tambahJadwal(BuildContext context) async {
  final kelas = await Repos.classes();
  final mapel = await Repos.subjects();
  if (!context.mounted) return;
  if (kelas.data.isEmpty || mapel.data.isEmpty) {
    showToast(context, 'Tambahkan kelas dan mapel lebih dahulu.',
        color: AppColors.danger);
    return;
  }

  String kelasSel = kelas.data.first['id'].toString();
  String mapelSel = mapel.data.first['id'].toString();
  String hariSel = 'Senin';

  final jamKeCtrl = TextEditingController(text: '1');
  final jamMulaiCtrl = TextEditingController(text: '07:00');
  final jamSelesaiCtrl = TextEditingController(text: '07:40');
  final ruangCtrl = TextEditingController();
  final tahunCtrl = TextEditingController(text: '2026/2027');

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setL) => AlertDialog(
        title: const Text('Tambah jadwal'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: kelasSel,
                decoration: const InputDecoration(labelText: 'Kelas'),
                items: [
                  for (final k in kelas.data)
                    DropdownMenuItem(
                        value: k['id'].toString(),
                        child: Text(k['nama']?.toString() ?? '-')),
                ],
                onChanged: (v) => setL(() => kelasSel = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: mapelSel,
                decoration: const InputDecoration(labelText: 'Mapel'),
                items: [
                  for (final m in mapel.data)
                    DropdownMenuItem(
                        value: m['id'].toString(),
                        child: Text(m['nama']?.toString() ?? '-')),
                ],
                onChanged: (v) => setL(() => mapelSel = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: hariSel,
                decoration: const InputDecoration(labelText: 'Hari'),
                items: const [
                  for (final h in [
                    'Senin',
                    'Selasa',
                    'Rabu',
                    'Kamis',
                    'Jumat',
                    'Sabtu'
                  ])
                    DropdownMenuItem(value: h, child: Text(h)),
                ],
                onChanged: (v) => setL(() => hariSel = v),
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: jamKeCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Jam ke- (angka)')),
              const SizedBox(height: 10),
              TextField(
                  controller: jamMulaiCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Jam mulai (07:00)')),
              const SizedBox(height: 10),
              TextField(
                  controller: jamSelesaiCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Jam selesai (07:40)')),
              const SizedBox(height: 10),
              TextField(
                  controller: ruangCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Ruang (opsional)')),
              const SizedBox(height: 10),
              TextField(
                  controller: tahunCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Tahun ajaran (2026/2027)')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan')),
        ],
      ),
    ),
  );
  if (ok != true) return;
  try {
    await Repos.db.from('schedules').insert({
      'class_id': kelasSel,
      'subject_id': mapelSel,
      'hari': hariSel,
      'jam_ke': int.tryParse(jamKeCtrl.text) ?? 1,
      'jam_mulai': jamMulaiCtrl.text.trim(),
      'jam_selesai': jamSelesaiCtrl.text.trim(),
      'ruang': ruangCtrl.text.trim().isEmpty ? null : ruangCtrl.text.trim(),
      'tahun_ajaran': tahunCtrl.text.trim(),
    });
    if (context.mounted) {
      showToast(context, 'Jadwal ditambahkan.', color: AppColors.success);
    }
  } catch (e) {
    if (context.mounted) _pesanError(context, e);
  }
}
