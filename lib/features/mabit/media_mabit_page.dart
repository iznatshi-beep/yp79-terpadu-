import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/session_profile.dart';
import '../../core/theme.dart';
import '../../services/lampiran.dart';
import '../../services/repositories.dart';
import '../../widgets/app_states.dart';
import '../../widgets/common.dart';

/// Media MABIT: upload dokumen/foto ke event, peserta buka (url_launcher).
/// Upload/publish: guru/admin. Hapus: admin (per RLS).
class MediaMabitPage extends StatefulWidget {
  const MediaMabitPage({super.key, required this.profile, this.eventId});

  final SessionProfile profile;
  final String? eventId; // kalau null, user pilih event

  @override
  State<MediaMabitPage> createState() => _MediaMabitPageState();
}

class _MediaMabitPageState extends State<MediaMabitPage> {
  bool _dimuat = false;
  bool _sibuk = false;
  String? _error;

  List<RowData> _events = [];
  String? _eventPilih;
  List<RowData> _media = [];

  String _deskripsi = '';

  @override
  void initState() {
    super.initState();
    _mulai();
  }

  Future<void> _mulai() async {
    setState(() {
      _dimuat = false;
      _error = null;
    });
    final ev = await Repos.mabitEvents();
    if (!mounted) return;
    if (ev.error != null) {
      setState(() {
        _error = ev.error;
        _dimuat = true;
      });
      return;
    }
    setState(() {
      _events = ev.data;
      _eventPilih = widget.eventId ??
          (ev.data.isNotEmpty ? ev.data.first['id']?.toString() : null);
      _dimuat = true;
    });
    if (_eventPilih != null) await _muatMedia(_eventPilih!);
  }

  Future<void> _muatMedia(String eventId) async {
    setState(() => _sibuk = true);
    final m = await Repos.mabitMedia(eventId);
    if (!mounted) return;
    setState(() {
      _media = m.data;
      _sibuk = false;
    });
  }

  Future<void> _pilihEvent(String? id) async {
    setState(() {
      _eventPilih = id;
      _media = [];
    });
    if (id != null) await _muatMedia(id);
  }

  Future<void> _unggah() async {
    if (_eventPilih == null) {
      showToast(context, 'Pilih event dulu.', color: AppColors.danger);
      return;
    }
    final url = await Lampiran.pickAndUpload(
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    );
    if (url == null) return; // user batal
    setState(() => _sibuk = true);
    final err = await Repos.unggahMabitMedia(
      eventId: _eventPilih!,
      fileUrl: url,
      deskripsi: _deskripsi.isEmpty ? null : _deskripsi,
      publikasikan: true,
    );
    if (!mounted) return;
    setState(() {
      _sibuk = false;
      _deskripsi = '';
    });
    if (err == null) {
      showToast(context, 'Media diunggah & dipublikasikan.');
      await _muatMedia(_eventPilih!);
    } else {
      showToast(context, err, color: AppColors.danger);
    }
  }

  Future<void> _bukaMedia(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      showToast(context, 'URL tidak valid.', color: AppColors.danger);
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!ok) showToast(context, 'Gagal membuka.', color: AppColors.danger);
  }

  Future<void> _hapusMedia(String id) async {
    final ok = await showConfirmDialog(
      context,
      judul: 'Hapus Media',
      pesan: 'File akan dihapus dari galeri MABIT.',
      tombolYa: 'Hapus',
      warnColor: AppColors.danger,
    );
    if (!ok) return;
    final err = await Repos.hapusMabitMedia(id);
    if (!mounted) return;
    if (err == null) {
      showToast(context, 'Media dihapus.');
      if (_eventPilih != null) await _muatMedia(_eventPilih!);
    } else {
      showToast(context, err, color: AppColors.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bisaUpload = widget.profile.isStaff || widget.profile.isAdmin;

    if (!_dimuat) return AppStates.loading(rows: 4);
    if (_error != null) {
      return AppStates.error(message: _error!, onRetry: _mulai);
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Media MABIT'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(onPressed: _mulai, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Pilih event
          Card(
            color: AppColors.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              side: const BorderSide(color: AppColors.line),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Event',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _eventPilih,
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12)),
                    items: _events
                        .map((e) => DropdownMenuItem(
                              value: e['id']?.toString(),
                              child: Text(e['nama_kegiatan']?.toString() ?? ''),
                            ))
                        .toList(),
                    onChanged: bisaUpload ? _pilihEvent : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Upload (hanya staff/admin)
          if (bisaUpload)
            Card(
              color: AppColors.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                side: const BorderSide(color: AppColors.line),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Unggah Media Baru',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink)),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration:
                          const InputDecoration(labelText: 'Deskripsi (opsional)'),
                      onChanged: (v) => setState(() => _deskripsi = v),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _sibuk ? null : _unggah,
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: const Text('Pilih & Unggah'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          // Galeri
          if (_media.isEmpty)
            AppStates.empty(
              judul: 'Belum ada media',
              pesan: 'Dokumen / foto MABIT akan tampil di sini.',
            )
          else
            ..._media.map((m) {
              final url = m['file_url']?.toString() ?? '';
              final desk = m['deskripsi']?.toString();
              final publik = m['dipublikasikan'] == true;
              final id = m['id']?.toString() ?? '';
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: AppColors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  side: const BorderSide(color: AppColors.line),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        publik ? AppColors.successBg : AppColors.warningBg,
                    child: Icon(
                      publik
                          ? Icons.visibility
                          : Icons.visibility_off,
                      size: 20,
                      color:
                          publik ? AppColors.success : AppColors.warning,
                    ),
                  ),
                  title: Text(
                    desk?.isNotEmpty == true ? desk : url.split('/').last,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    publik ? 'Dipublikasikan' : 'Draf (tidak tampil)',
                    style: TextStyle(
                        fontSize: 11.5,
                        color:
                            publik ? AppColors.success : AppColors.warning),
                  ),
                  isThreeLine: false,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _bukaMedia(url),
                        icon:
                            const Icon(Icons.open_in_new, size: 20),
                        tooltip: 'Buka',
                      ),
                      if (widget.profile.isAdmin)
                        IconButton(
                          onPressed: () => _hapusMedia(id),
                          icon:
                              const Icon(Icons.delete_outline, size: 20),
                          color: AppColors.danger,
                          tooltip: 'Hapus',
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
