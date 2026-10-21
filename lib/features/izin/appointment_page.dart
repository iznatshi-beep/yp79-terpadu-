import 'package:flutter/material.dart';

import '../../core/models/session_profile.dart';
import '../../core/theme.dart';
import '../../services/repositories.dart';
import '../../widgets/common.dart';

/// Halaman appointment (jadwal pertemuan ortu-guru):
/// - Ortu: ajukan janji temu ke guru
/// - Guru: terima / tolak / tandai selesai
/// - Admin: pantau semua
class AppointmentPage extends StatefulWidget {
  const AppointmentPage({super.key, required this.profile});
  final SessionProfile profile;

  @override
  State<AppointmentPage> createState() => _AppointmentPageState();
}

class _AppointmentPageState extends State<AppointmentPage> {
  bool _dataDimuat = true;
  final _items = <RowData>[];

  // Ajukan (ortu)
  bool _tampilAjukan = false;
  String? _guruId;
  String _topik = '', _tanggal = '', _jam = '';
  String _metode = 'tatap_muka';
  String _catatan = '';
  bool _sibukAjukan = false;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _dataDimuat = true);
    try {
      final isParent = widget.profile.isParent;
      final isGuru = widget.profile.isStaff && !widget.profile.isAdmin;
      final isAdmin = widget.profile.isAdmin;

      // Ortu: lihat yang dia ajukan
      // Guru: lihat yang datang ke dia
      // Admin: lihat semua
      final uid = Repos.uid;

      // Cache nama guru
      final guruRows = await Repos.db
          .from('profiles')
          .select('id, nama')
          .eq('role', 'guru')
          .limit(100);
      for (final g in guruRows) {
        _guruNamaCache[g['id']?.toString() ?? ''] = g['nama']?.toString() ?? '';
      }

      if (isParent) {
        final r = await Repos.db
            .from('appointments')
            .select('*, profiles(nama)')
            .eq('diajukan_oleh', uid)
            .order('created_at', ascending: false)
            .limit(100);
        if (!mounted) return;
        setState(() {
          _dataDimuat = false;
          _items
              .addAll([for (final x in r) Map<String, dynamic>.from(x as Map)]);
        });
      } else if (isGuru) {
        final r = await Repos.db
            .from('appointments')
            .select('*, profiles(nama)')
            .eq('guru_user_id', uid)
            .order('tanggal')
            .limit(200);
        if (!mounted) return;
        setState(() {
          _dataDimuat = false;
          _items
              .addAll([for (final x in r) Map<String, dynamic>.from(x as Map)]);
        });
      } else {
        final r = await Repos.db
            .from('appointments')
            .select('*, profiles(nama)')
            .order('created_at', ascending: false)
            .limit(200);
        if (!mounted) return;
        setState(() {
          _dataDimuat = false;
          _items
              .addAll([for (final x in r) Map<String, dynamic>.from(x as Map)]);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _dataDimuat = false);
    }
  }

  Future<void> _ajukan() async {
    if (_guruId == null) {
      showToast(context, 'Pilih guru.', color: AppColors.danger);
      return;
    }
    if (_topik.trim().isEmpty) {
      showToast(context, 'Topik wajib diisi.', color: AppColors.danger);
      return;
    }
    if (_tanggal.trim().isEmpty) {
      showToast(context, 'Tanggal wajib diisi.', color: AppColors.danger);
      return;
    }
    if (_jam.trim().isEmpty) {
      showToast(context, 'Jam wajib diisi.', color: AppColors.danger);
      return;
    }

    setState(() => _sibukAjukan = true);
    try {
      await Repos.db.from('appointments').insert({
        'diajukan_oleh': Repos.uid,
        'guru_user_id': _guruId,
        'topik': _topik.trim(),
        'tanggal': _tanggal.trim(),
        'jam': _jam.trim(),
        'metode': _metode,
        'catatan': _catatan.trim().isEmpty ? null : _catatan.trim(),
      });
      if (!mounted) return;
      setState(() {
        _sibukAjukan = false;
        _tampilAjukan = false;
        _topik = '';
        _tanggal = '';
        _jam = '';
        _metode = 'tatap_muka';
        _catatan = '';
        _guruId = null;
      });
      showToast(context, 'Jadwal diajukan ✓', color: AppColors.success);
      _muat();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sibukAjukan = false);
      showToast(context, 'Gagal: $e', color: AppColors.danger);
    }
  }

  Future<void> _putuskan(RowData item, String status) async {
    final id = item['id']?.toString();
    if (id == null) return;
    try {
      await Repos.db
          .from('appointments')
          .update({
            'status': status,
            'keputusan_oleh': Repos.uid,
            'catatan_keputusan': status == 'selesai'
                ? 'Ditandai selesai'
                : status == 'ditolak'
                    ? 'Ditolak'
                    : 'Diterima',
          })
          .eq('id', id);
      showToast(context, 'Status diperbarui ✓', color: AppColors.success);
      _muat();
    } catch (e) {
      showToast(context, 'Gagal: $e', color: AppColors.danger);
    }
  }

  String? _guruNama(RowData item) {
    // guru_user_id points to profiles.id
    final guruId = item['guru_user_id']?.toString();
    if (guruId != null && _guruNamaCache.containsKey(guruId)) {
      return _guruNamaCache[guruId];
    }
    return 'Guru';
  }
  final Map<String, String> _guruNamaCache = {};

  String _statusLabel(String s) {
    switch (s) {
      case 'diajukan':
        return 'Diajukan';
      case 'diterima':
        return 'Diterima';
      case 'ditolak':
        return 'Ditolak';
      case 'selesai':
        return 'Selesai';
      case 'dibatalkan':
        return 'Dibatalkan';
      default:
        return s;
    }
  }

  Color _statusWarna(String s) {
    switch (s) {
      case 'diajukan':
        return AppColors.warning;
      case 'diterima':
        return AppColors.success;
      case 'ditolak':
        return AppColors.danger;
      case 'selesai':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isParent = widget.profile.isParent;
    final isGuru = widget.profile.isStaff && !widget.profile.isAdmin;
    final isAdmin = widget.profile.isAdmin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Jadwal Pertemuan'),
        actions: [
          if (isParent)
            IconButton(
              icon: const Icon(Icons.add_outlined),
              onPressed: () => setState(() => _tampilAjukan = !_tampilAjukan),
            ),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _muat),
        ],
      ),
      body: Column(
        children: [
          if (isParent && _tampilAjukan) _buildFormAjukan(),
          Expanded(
            child: _dataDimuat
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _items.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                            child: Text('Belum ada jadwal.',
                                style: TextStyle(fontSize: 13))),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(18),
                        itemCount: _items.length,
                        itemBuilder: (context, i) {
                          final item = _items[i];
                          final status = item['status']?.toString() ?? '';
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item['topik']?.toString() ?? '-',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color:
                                              _statusWarna(status).withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _statusLabel(status),
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: _statusWarna(status)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Guru: ${_guruNama(item)} • ${item['tanggal']?.toString() ?? '-'} • ${item['jam']?.toString() ?? '-'} • ${item['metode']?.toString() ?? '-'}',
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textSecondary),
                                  ),
                                  if (item['catatan'] != null &&
                                      item['catatan']!.toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        item['catatan'].toString(),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary),
                                      ),
                                    ),
                                  if (item['catatan_keputusan'] != null &&
                                      item['catatan_keputusan']!
                                          .toString()
                                          .isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Keputusan: ${item['catatan_keputusan']}',
                                        style: const TextStyle(
                                            fontSize: 11.5,
                                            color: AppColors.textSecondary),
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  if (isGuru || isAdmin) ...[
                                    if (status == 'diajukan')
                                      Row(
                                        children: [
                                          Expanded(
                                            child: FilledButton(
                                              onPressed: () =>
                                                  _putuskan(item, 'diterima'),
                                              child: const Text('Terima',
                                                  style: TextStyle(
                                                      fontSize: 12)),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () =>
                                                  _putuskan(item, 'ditolak'),
                                              child: Text('Tolak',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors.danger)),
                                            ),
                                          ),
                                        ],
                                      )
                                    else if (status == 'diterima')
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () =>
                                                  _putuskan(item, 'selesai'),
                                              child: const Text(
                                                  'Tandai Selesai',
                                                  style: TextStyle(fontSize: 12)),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () =>
                                                  _putuskan(item, 'dibatalkan'),
                                              child: Text('Batalkan',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors.danger)),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormAjukan() {
    // Muat daftar guru
    return Card(
      margin: const EdgeInsets.all(18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Ajukan Jadwal',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            // Dropdown guru - muat dari profiles with role guru
            FutureBuilder<List<RowData>>(
              future: Repos.db
                  .from('profiles')
                  .select()
                  .eq('role', 'guru')
                  .limit(50),
              builder: (context, snapshot) {
                final guruList = snapshot.data ?? [];
                return DropdownButtonFormField<String>(
                  value: _guruId,
                  decoration: const InputDecoration(
                      labelText: 'Guru *',
                      border: OutlineInputBorder()),
                  items: [
                    for (final g in guruList)
                      DropdownMenuItem(
                          value: g['id']?.toString(),
                          child: Text(g['nama']?.toString() ?? '-')),
                  ],
                  onChanged: (v) => setState(() => _guruId = v),
                );
              },
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => _topik = v,
              decoration:
                  const InputDecoration(labelText: 'Topik *'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => _tanggal = v,
                    decoration:
                        const InputDecoration(labelText: 'Tanggal *'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: (v) => _jam = v,
                    decoration: const InputDecoration(
                        labelText: 'Jam *'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _metode,
              decoration:
                  const InputDecoration(labelText: 'Metode'),
              items: [
                const DropdownMenuItem(
                    value: 'tatap_muka', child: Text('Tatap muka')),
                const DropdownMenuItem(value: 'online', child: Text('Online')),
                const DropdownMenuItem(
                    value: 'telepon', child: Text('Telepon')),
              ],
              onChanged: (v) => setState(() => _metode = v ?? 'tatap_muka'),
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => _catatan = v,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'Catatan (opsional)'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _sibukAjukan ? null : _ajukan,
              child: _sibukAjukan
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Text('Ajukan'),
            ),
          ],
        ),
      ),
    );
  }
}
