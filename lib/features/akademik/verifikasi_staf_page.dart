import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/repositories.dart';
import '../../widgets/app_states.dart';
import '../../widgets/common.dart';

/// Verifikasi staf — SATU halaman untuk semua yang perlu dicek guru/admin:
/// Tab 1: Izin (diajukan → setujui/tolak)
/// Tab 2: Mutaba'ah hari ini (tandai sudah diverifikasi)
/// Tab 3: Setoran hafalan (setujui/tolak)
class VerifikasiStafPage extends StatefulWidget {
  const VerifikasiStafPage({super.key});

  @override
  State<VerifikasiStafPage> createState() => _VerifikasiStafPageState();
}

class _VerifikasiStafPageState extends State<VerifikasiStafPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Verifikasi'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Izin'),
            Tab(text: "Mutaba'ah"),
            Tab(text: 'Hafalan'),
          ]),
        ),
        body: const TabBarView(
          children: [
            _TabIzin(),
            _TabMutabaah(),
            _TabHafalan(),
          ],
        ),
      ),
    );
  }
}

// =============================== IZIN =======================================
class _TabIzin extends StatefulWidget {
  const _TabIzin();

  @override
  State<_TabIzin> createState() => _TabIzinState();
}

class _TabIzinState extends State<_TabIzin> {
  bool _memuat = true;
  List<RowData> _izin = const [];

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _memuat = true);
    final res = await Repos.leaves(status: 'diajukan');
    if (!mounted) return;
    setState(() {
      _izin = res.data;
      _memuat = false;
    });
  }

  Future<void> _putuskan(RowData z, String status) async {
    final ok = await Repos.decideLeave(
        id: z['id']?.toString() ?? '', status: status);
    if (!mounted) return;
    showToast(context, ok ? 'Keputusan tersimpan.' : 'Gagal menyimpan.',
        color: ok ? AppColors.success : AppColors.danger);
    _muat();
  }

  @override
  Widget build(BuildContext context) {
    if (_memuat) {
      return const Padding(padding: EdgeInsets.all(18), child: SkeletonRow());
    }
    if (_izin.isEmpty) {
      return const EmptyState(
        title: 'Tidak ada izin menunggu',
        message: 'Pengajuan izin baru akan muncul di sini.',
        icon: Icons.event_busy_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: _izin.length,
        itemBuilder: (context, i) {
          final z = _izin[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(
                  '${z['jenis'] ?? '-'} · ${z['mulai']?.toString().split('T').first ?? '-'}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
              subtitle: Text(
                'Alasan: ${z['alasan'] ?? '-'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textSecondary),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.danger),
                    onPressed: () async {
                      final ok = await Repos.decideLeave(
                          id: z['id']?.toString() ?? '', status: 'ditolak');
                      if (!mounted) return;
                      showToast(context,
                          ok ? 'Izin ditolak.' : 'Gagal menyimpan.',
                          color: ok ? AppColors.success : AppColors.danger);
                      _muat();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        color: AppColors.success),
                    onPressed: () async {
                      final ok = await Repos.decideLeave(
                          id: z['id']?.toString() ?? '',
                          status: 'disetujui');
                      if (!mounted) return;
                      showToast(context,
                          ok ? 'Izin disetujui.' : 'Gagal menyimpan.',
                          color: ok
                              ? AppColors.success
                              : AppColors.danger);
                      _muat();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================ MUTABAAH ======================================
class _TabMutabaah extends StatefulWidget {
  const _TabMutabaah();

  @override
  State<_TabMutabaah> createState() => _TabMutabaahState();
}

class _TabMutabaahState extends State<_TabMutabaah> {
  bool _memuat = true;
  List<RowData> _entries = const [];

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final res = await Repos.mutabaahHariIni();
    if (!mounted) return;
    setState(() {
      _entries = res.data;
      _memuat = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_memuat) {
      return const Padding(padding: EdgeInsets.all(18), child: SkeletonRow());
    }
    if (_entries.isEmpty) {
      return const EmptyState(
        title: 'Belum ada isian hari ini',
        message:
            "Jurnal mutaba'ah siswa hari ini akan muncul di sini.",
        icon: Icons.checklist_rounded,
      );
    }
    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: _entries.length,
        itemBuilder: (context, i) {
          final m = _entries[i];
          final ceklis = m['checklist'] is Map
              ? m['checklist'] as Map
              : <dynamic, dynamic>{};
          final terisi =
              ceklis.values.where((v) => v == true).length;
          final diverifikasi = m['diverifikasi'] == true;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text('Siswa: ${(m['student_user_id']?.toString() ?? '').substring(0, 8)}…',
                  style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                  '$terisi dari ${ceklis.length} ibadah tercentang',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textSecondary)),
              trailing: diverifikasi
                  ? const Icon(Icons.check_circle_rounded,
                      color: AppColors.success)
                  : FilledButton.tonal(
                      onPressed: () async {
                        final err = await Repos.verifikasiMutabaah(
                            m['id']?.toString() ?? '');
                        if (!mounted) return;
                        showToast(context,
                            err ?? "Mutaba'ah diverifikasi.",
                            color: err == null
                                ? AppColors.success
                                : AppColors.danger);
                        _muat();
                      },
                      child: const Text('Verifikasi'),
                    ),
            ),
          );
        },
      ),
    );
  }
}

// =============================== HAFALAN ====================================
class _TabHafalan extends StatefulWidget {
  const _TabHafalan();

  @override
  State<_TabHafalan> createState() => _TabHafalanState();
}

class _TabHafalanState extends State<_TabHafalan> {
  bool _memuat = true;
  List<RowData> _hafalan = const [];

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final res = await Repos.hafalanMenunggu();
    if (!mounted) return;
    setState(() {
      _hafalan = res.data;
      _memuat = false;
    });
  }

  Future<void> _putuskan(RowData h, bool setuju) async {
    String? alasan;
    if (!setuju) {
      final ctrl = TextEditingController();
      final lanjut = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tolak setoran?'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
                labelText: 'Alasan penolakan (opsional)'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Tolak')),
          ],
        ),
      );
      if (lanjut != true) return;
      alasan = ctrl.text.trim().isEmpty ? null : ctrl.text.trim();
    }
    final err = await Repos.verifikasiHafalan(
        id: h['id']?.toString() ?? '', setuju: setuju, alasanPenolakan: alasan);
    if (!mounted) return;
    showToast(context,
        err ?? (setuju ? 'Setoran disetujui.' : 'Setoran ditolak.'),
        color: err == null ? AppColors.success : AppColors.danger);
    _muat();
  }

  @override
  Widget build(BuildContext context) {
    if (_memuat) {
      return const Padding(padding: EdgeInsets.all(18), child: SkeletonRow());
    }
    if (_hafalan.isEmpty) {
      return const EmptyState(
        title: 'Tidak ada setoran menunggu',
        message: 'Setoran hafalan siswa akan tampil di sini.',
        icon: Icons.menu_book_rounded,
      );
    }
    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: _hafalan.length,
        itemBuilder: (context, i) {
          final h = _hafalan[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Capaian: ${h['capaian'] ?? '-'}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  if (h['catatan'] != null)
                    Text('Catatan: ${h['catatan']}',
                        style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary)),
                  if (h['lampiran_url'] != null) ...[
                    const SizedBox(height: 4),
                    const Text('📎 Ada lampiran audio/video',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.primary)),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _putuskan(h, false),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('Tolak'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _putuskan(h, true),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Setujui'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

}