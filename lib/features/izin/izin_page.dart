import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/role.dart';
import '../../../core/models/session_profile.dart';
import '../../../core/theme.dart';
import '../../../services/lampiran.dart';
import '../../../services/repositories.dart';
import '../../../widgets/app_states.dart';
import '../../../widgets/common.dart';

/// Pengajuan izin/sakit digital.
///
/// Sisi orang tua & siswa: mengajukan izin (`Repos.submitLeave`).
/// Sisi guru & admin: memeriksa dan memutuskan (`Repos.decideLeave`).
/// Sebelum audit, kedua fungsi ini tidak dipanggil UI mana pun — pengajuan izin
/// hanya ada di database.
class IzinPage extends StatefulWidget {
  const IzinPage({super.key, required this.profile});

  final SessionProfile profile;

  @override
  State<IzinPage> createState() => _IzinPageState();
}

class _IzinPageState extends State<IzinPage> {
  bool _loading = true;
  String? _error;
  List<RowData> _izin = const [];
  List<RowData> _anak = const [];

  bool get _staf =>
      widget.profile.role == Role.admin ||
      widget.profile.role == Role.guru ||
      widget.profile.role == Role.guruPembimbing;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (!_staf) {
      var ids = <String>[];
      if (widget.profile.role == Role.orangTua) {
        ids = widget.profile.parentStudentIds;
      } else {
        final id = widget.profile.studentId ?? Repos.uid;
        if (id.isNotEmpty) ids = [id];
      }
      final anak = await Repos.studentsByIds(ids);
      if (!mounted) return;
      _anak = anak.data;
    }

    final izin = await Repos.leaves();
    if (!mounted) return;
    setState(() {
      _izin = izin.data;
      _error = izin.error;
      _loading = false;
    });
  }

  Future<void> _ajukan() async {
    if (_anak.isEmpty) {
      showToast(context, 'Belum ada siswa yang terhubung ke akun Anda.',
          color: AppColors.warning);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormIzin(anak: _anak, onSimpan: _muat),
    );
  }

  Future<void> _putuskan(RowData izin, String status) async {
    final catatanCtrl = TextEditingController();
    final lanjut = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(status == 'disetujui'
            ? 'Setujui pengajuan izin?'
            : 'Tolak pengajuan izin?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${izin['jenis']} · ${izin['mulai']} s/d ${izin['selesai'] ?? izin['mulai']}\n'
              'Alasan: ${izin['alasan'] ?? '-'}',
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: catatanCtrl,
              decoration: const InputDecoration(
                labelText: 'Catatan keputusan (opsional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (lanjut != true || !mounted) return;

    final ok = await Repos.decideLeave(
      id: izin['id']?.toString() ?? '',
      status: status,
      catatan: catatanCtrl.text.trim().isEmpty ? null : catatanCtrl.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      showToast(context, 'Keputusan tersimpan.', color: AppColors.success);
      await _muat();
    } else {
      showToast(
        context,
        'Gagal menyimpan keputusan. Periksa kewenangan Anda pada kelas ini.',
        color: AppColors.danger,
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      showToast(context, 'Gagal membuka file.', color: AppColors.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengajuan Izin')),
      body: _body(),
      floatingActionButton: _staf
          ? null
          : FloatingActionButton.extended(
              onPressed: _loading ? null : _ajukan,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajukan Izin'),
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
      return ErrorState(message: _error!, onRetry: _muat);
    }
    if (_izin.isEmpty) {
      return EmptyState(
        title: 'Belum ada pengajuan',
        message: _staf
            ? 'Pengajuan izin dari orang tua/siswa akan tampil di sini.'
            : 'Tekan "Ajukan Izin" untuk mengirim pengajuan baru.',
        icon: Icons.event_busy_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 92),
        itemCount: _izin.length,
        itemBuilder: (context, i) {
          final z = _izin[i];
          final status = z['status']?.toString() ?? 'diajukan';
          final badge = switch (status) {
            'disetujui' => (BadgeState.success, 'Disetujui'),
            'ditolak' => (BadgeState.danger, 'Ditolak'),
            'diproses' => (BadgeState.warning, 'Diproses'),
            _ => (BadgeState.info, 'Diajukan'),
          };
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(18),
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
                    StatusBadge(label: badge.$2, state: badge.$1),
                    const Spacer(),
                    Text(
                      '${z['jenis'] ?? '-'}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${z['mulai'] ?? '-'} s/d ${z['selesai'] ?? z['mulai'] ?? '-'}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  z['alasan']?.toString() ?? '-',
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textSecondary),
                ),
                if (z['catatan_keputusan'] != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Catatan sekolah: ${z['catatan_keputusan']}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textPrimary),
                  ),
                ],
                if (z['lampiran_url'] != null &&
                (z['lampiran_url']?.toString().isNotEmpty ?? false)) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () =>
                    _launchUrl(z['lampiran_url']?.toString() ?? ''),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file_rounded, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Lihat lampiran',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
            if (_staf && status == 'diajukan') ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _putuskan(z, 'ditolak'),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('Tolak'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _putuskan(z, 'disetujui'),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Setujui'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FormIzin extends StatefulWidget {
  const _FormIzin({required this.anak, required this.onSimpan});

  final List<RowData> anak;
  final Future<void> Function() onSimpan;

  @override
  State<_FormIzin> createState() => _FormIzinState();
}

class _FormIzinState extends State<_FormIzin> {
  String? _anakId;
  String _jenis = 'izin';
  DateTime _mulai = DateTime.now();
  DateTime? _selesai;
  final _alasan = TextEditingController();
  bool _kirim = false;
  String? _lampiranUrl;
  String? _lampiranNama;

  @override
  void initState() {
    super.initState();
    _anakId = widget.anak.first['user_id']?.toString();
  }

  @override
  void dispose() {
    _alasan.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickLampiran() async {
    final picked = await Lampiran.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (picked == null || !mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
          child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Mengunggah lampiran…'),
                  ]))),
    );
    final bytes = File(picked.path).readAsBytesSync();
    final url =
        await Lampiran.upload(bytes, picked.name, mimeType: picked.mime);
    if (!mounted) return;
    Navigator.pop(context);
    if (url != null && url.isNotEmpty) {
      setState(() {
        _lampiranUrl = url;
        _lampiranNama = picked.name;
      });
    } else {
      showToast(context, 'Gagal upload lampiran.', color: AppColors.danger);
    }
  }

  Future<void> _pilihTanggal(bool mulai) async {
    final t = await showDatePicker(
      context: context,
      initialDate: mulai ? _mulai : (_selesai ?? _mulai),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (t == null) return;
    setState(() {
      if (mulai) {
        _mulai = t;
        if (_selesai != null && _selesai!.isBefore(t)) _selesai = t;
      } else {
        _selesai = t;
      }
    });
  }

  Future<void> _simpan() async {
    if (_anakId == null) return;
    if (_alasan.text.trim().length < 5) {
      showToast(context, 'Alasan wajib diisi (minimal 5 karakter).',
          color: AppColors.warning);
      return;
    }
    setState(() => _kirim = true);
    final ok = await Repos.submitLeave(
      studentId: _anakId!,
      mulai: _fmt(_mulai),
      selesai: _selesai == null ? null : _fmt(_selesai!),
      jenis: _jenis,
      alasan: _alasan.text.trim(),
      lampiranUrl: _lampiranUrl,
    );
    if (!mounted) return;
    setState(() => _kirim = false);

    if (ok) {
      Navigator.pop(context);
      showToast(context, 'Pengajuan izin terkirim.', color: AppColors.success);
      await widget.onSimpan();
    } else {
      showToast(
        context,
        'Gagal mengirim pengajuan. Pastikan akun Anda terhubung dengan siswa '
        'yang terverifikasi.',
        color: AppColors.danger,
        durasi: 6,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Formulir Pengajuan Izin',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _anakId,
              decoration: const InputDecoration(labelText: 'Siswa'),
              items: [
                for (final a in widget.anak)
                  DropdownMenuItem(
                    value: a['user_id']?.toString(),
                    child: Text(a['nama_lengkap']?.toString() ?? '-'),
                  ),
              ],
              onChanged: (v) => setState(() => _anakId = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _jenis,
              decoration: const InputDecoration(labelText: 'Jenis'),
              items: const [
                DropdownMenuItem(value: 'izin', child: Text('Izin')),
                DropdownMenuItem(value: 'sakit', child: Text('Sakit')),
              ],
              onChanged: (v) => setState(() => _jenis = v ?? 'izin'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pilihTanggal(true),
                    icon: const Icon(Icons.event_outlined, size: 16),
                    label: Text('Mulai: ${_fmt(_mulai)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pilihTanggal(false),
                    icon: const Icon(Icons.event_available_outlined, size: 16),
                    label: Text(_selesai == null
                        ? 'Selesai: 1 hari'
                        : 'Selesai: ${_fmt(_selesai!)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _alasan,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Alasan',
                hintText: 'Contoh: demam, ada surat dokter',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _kirim ? null : _pickLampiran,
              icon: _kirim
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary))
                  : const Icon(Icons.attach_file_rounded, size: 16),
              label: Text(_lampiranNama != null
                  ? 'Lampiran: $_lampiranNama ✓'
                  : 'Lampirkan surat dokter / bukti (opsional)'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _kirim ? null : _simpan,
              icon: _kirim
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: const Text('Kirim Pengajuan'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Lampiran surat dokter belum tersedia: upload file (Supabase '
              'Storage) belum dikonfigurasi pada versi ini.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
