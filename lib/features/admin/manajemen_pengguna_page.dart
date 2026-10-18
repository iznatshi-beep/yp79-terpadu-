import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../services/repositories.dart';
import '../../../widgets/app_states.dart';
import '../../../widgets/common.dart';

/// Manajemen Pengguna — halaman admin untuk membuat dan mengelola akun.
///
/// SEBELUMNYA TIDAK ADA SAMA SEKALI. Akun hanya bisa lahir dari SQL manual,
/// padahal halaman login dengan benar menolak pendaftaran mandiri ("akun dibuat
/// pihak sekolah"). Akibatnya sekolah tidak bisa memakai aplikasinya.
///
/// Semua tindakan di halaman ini memanggil RPC yang memeriksa `is_admin()` di
/// server. Menyembunyikan tombol bukan pengaman, dan halaman ini pun akan
/// menampilkan pesan penolakan bila server menolak.
class ManajemenPenggunaPage extends StatefulWidget {
  const ManajemenPenggunaPage({super.key});

  @override
  State<ManajemenPenggunaPage> createState() => _ManajemenPenggunaPageState();
}

enum _Filter { semua, admin, guru, guruPembimbing, siswa, orangTua }

extension on _Filter {
  String get label => switch (this) {
        _Filter.semua => 'Semua',
        _Filter.admin => 'Admin',
        _Filter.guru => 'Guru',
        _Filter.guruPembimbing => 'Pembimbing',
        _Filter.siswa => 'Siswa',
        _Filter.orangTua => 'Orang Tua',
      };

  /// Nilai yang tersimpan di kolom `profiles.role`.
  String? get nilai => switch (this) {
        _Filter.semua => null,
        _Filter.admin => 'admin',
        _Filter.guru => 'guru',
        _Filter.guruPembimbing => 'guru_pembimbing',
        _Filter.siswa => 'siswa',
        _Filter.orangTua => 'orang_tua',
      };
}

class _ManajemenPenggunaPageState extends State<ManajemenPenggunaPage> {
  bool _memuat = true;
  String? _error;
  List<RowData> _pengguna = const [];
  Map<String, bool> _aktif = const {};
  _Filter _filter = _Filter.semua;
  String _cari = '';

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _memuat = _pengguna.isEmpty;
      _error = null;
    });

    final hasil = await Repos.listPengguna();
    final status = await Repos.statusAkun();
    if (!mounted) return;

    final peta = <String, bool>{};
    for (final s in status.data) {
      final id = s['user_id']?.toString();
      if (id != null) peta[id] = s['aktif'] == true;
    }

    setState(() {
      _pengguna = hasil.data;
      _aktif = peta;
      _error = hasil.error ?? status.error;
      _memuat = false;
    });
  }

  List<RowData> get _tersaring {
    final q = _cari.trim().toLowerCase();
    return [
      for (final p in _pengguna)
        if ((_filter.nilai == null || p['role']?.toString() == _filter.nilai) &&
            (q.isEmpty ||
                (p['nama']?.toString().toLowerCase().contains(q) ?? false) ||
                (p['email']?.toString().toLowerCase().contains(q) ?? false)))
          p
    ];
  }

  /// Akun tanpa profil (mis. dibuat lewat dashboard Supabase) tetap tampil,
  /// statusnya "belum lengkap" — bukan disembunyikan, karena admin perlu tahu.
  bool _lengkap(RowData p) =>
      (p['nama']?.toString().isNotEmpty ?? false) && p['role'] != null;

  void _pesan(String teks, {bool sukses = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(teks),
        backgroundColor: sukses ? AppColors.success : AppColors.danger,
        duration: Duration(seconds: sukses ? 3 : 7),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manajemen Pengguna'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _muat,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _bukaFormBuat,
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
        label: const Text('Buat akun'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: TextField(
              onChanged: (v) => setState(() => _cari = v),
              decoration: const InputDecoration(
                hintText: 'Cari nama atau email',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              children: [
                for (final f in _Filter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _PilFilter(
                      label: f.label,
                      aktif: _filter == f,
                      jumlah: f.nilai == null
                          ? _pengguna.length
                          : _pengguna
                              .where((p) => p['role']?.toString() == f.nilai)
                              .length,
                      onTap: () => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _isi()),
        ],
      ),
    );
  }

  Widget _isi() {
    if (_memuat) return const Padding(padding: EdgeInsets.all(18), child: SkeletonRow());
    if (_error != null) return ErrorState(message: _error!, onRetry: _muat);

    final baris = _tersaring;
    if (baris.isEmpty) {
      return EmptyState(
        title: _pengguna.isEmpty ? 'Belum ada akun' : 'Tidak ada yang cocok',
        message: _pengguna.isEmpty
            ? 'Tekan "Buat akun" untuk membuat akun pertama (mis. guru atau siswa).'
            : 'Coba kata kunci atau filter lain.',
        icon: Icons.group_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 96),
        itemCount: baris.length,
        itemBuilder: (context, i) => _kartu(baris[i]),
      ),
    );
  }

  Widget _kartu(RowData p) {
    final id = p['id']?.toString() ?? '';
    final nama = p['nama']?.toString();
    final aktif = _aktif[id];
    final role = p['role']?.toString() ?? '-';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: appSoftShadow,
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            InitialAvatar(name: nama ?? (p['email']?.toString() ?? '?'), size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nama?.isNotEmpty == true ? nama! : '(belum ada profil)',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: nama?.isNotEmpty == true
                          ? AppColors.ink
                          : AppColors.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p['email']?.toString() ?? '-',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      StatusBadge(label: _labelRole(role), state: _warnaRole(role)),
                      const SizedBox(width: 6),
                      if (!_lengkap(p))
                        const StatusBadge(
                            label: 'Profil belum lengkap',
                            state: BadgeState.warning)
                      else if (aktif == false)
                        const StatusBadge(
                            label: 'Nonaktif', state: BadgeState.danger)
                      else if (aktif == true)
                        const StatusBadge(
                            label: 'Aktif', state: BadgeState.success),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Kelola',
              onPressed: () => _bukaKelola(p),
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ],
        ),
      ),
    );
  }

  String _labelRole(String r) => switch (r) {
        'admin' => 'Admin',
        'guru' => 'Guru',
        'guru_pembimbing' => 'Pembimbing',
        'siswa' => 'Siswa',
        'orang_tua' => 'Orang Tua',
        _ => r,
      };

  BadgeState _warnaRole(String r) => switch (r) {
        // BadgeState hanya punya lima keadaan; admin dibedakan dengan `info`
        // dan teks perannya, bukan warna baru.
        'admin' => BadgeState.info,
        'guru' || 'guru_pembimbing' => BadgeState.neutral,
        'orang_tua' => BadgeState.warning,
        _ => BadgeState.success,
      };

  // ---------------------------------------------------------------- buat akun

  Future<void> _bukaFormBuat() async {
    final kelas = await Repos.listKelas();
    if (!mounted) return;
    final hasil = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormBuatAkun(kelas: kelas.data),
    );
    if (hasil == true) await _muat();
  }

  // --------------------------------------------------------------- kelola akun

  Future<void> _bukaKelola(RowData p) async {
    final id = p['id']?.toString() ?? '';
    final nama = p['nama']?.toString() ?? p['email']?.toString() ?? '-';
    final role = p['role']?.toString() ?? 'siswa';
    final aktif = _aktif[id] ?? true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(nama,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800,
                      color: AppColors.ink)),
              const SizedBox(height: 4),
              Text(p['email']?.toString() ?? '-',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Ubah peran'),
                subtitle: Text('Sekarang: ${_labelRole(role)}'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _ubahPeran(id, nama, role);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link_rounded),
                title: const Text('Hubungkan ke anak (orang tua)'),
                subtitle: const Text('Menetapkan relasi orang tua dengan siswa'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _hubungkanAnak(id, nama, role);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_reset_rounded),
                title: const Text('Kirim tautan reset kata sandi'),
                subtitle: const Text('Tautan dikirim ke email pengguna'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final err = await Repos.adminResetPassword(
                      p['email']?.toString() ?? '');
                  _pesan(err ?? 'Tautan reset dikirim ke ${p['email']}.',
                      sukses: err == null);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(aktif
                    ? Icons.person_off_outlined
                    : Icons.person_outline_rounded),
                title: Text(aktif ? 'Nonaktifkan akun' : 'Aktifkan kembali'),
                subtitle: Text(aktif
                    ? 'Pengguna tidak bisa masuk sampai diaktifkan lagi'
                    : 'Pengguna boleh masuk kembali'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final err = await Repos.adminSetAktif(id, !aktif);
                  _pesan(err ?? (aktif ? 'Akun dinonaktifkan.' : 'Akun diaktifkan.'),
                      sukses: err == null);
                  await _muat();
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.danger),
                title: const Text('Hapus akun',
                    style: TextStyle(color: AppColors.danger)),
                subtitle: const Text('Menghapus akun beserta data yang '
                    'terhubung (tidak dapat dibatalkan)'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final yakin = await showConfirmDialog(
                    context,
                    judul: 'Hapus akun $nama?',
                    pesan: 'Akun, profil, dan data yang terhubung akan dihapus '
                        'permanen dan tercatat di audit log. Tindakan ini tidak '
                        'dapat dibatalkan.',
                    tombolYa: 'Hapus',
                  );
                  if (yakin != true) return;
                  final err = await Repos.adminHapusUser(id);
                  _pesan(err ?? 'Akun $nama dihapus.', sukses: err == null);
                  await _muat();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _ubahPeran(String id, String nama, String roleSekarang) async {
    String pilih = roleSekarang;
    final ctrl = TextEditingController();

    final lanjut = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Ubah peran $nama'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: pilih,
                decoration: const InputDecoration(labelText: 'Peran baru'),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'guru', child: Text('Guru')),
                  DropdownMenuItem(
                      value: 'guru_pembimbing', child: Text('Guru Pembimbing')),
                  DropdownMenuItem(value: 'siswa', child: Text('Siswa')),
                  DropdownMenuItem(value: 'orang_tua', child: Text('Orang Tua')),
                ],
                onChanged: (v) => setLocal(() => pilih = v ?? pilih),
              ),
              if (pilih == 'siswa') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(
                    labelText: 'NIS (wajib bila belum ada)',
                  ),
                ),
              ],
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
      ),
    );

    if (lanjut != true) return;
    final err = await Repos.adminSetRole(
      userId: id,
      role: pilih,
      identitas: ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
    );
    _pesan(err ?? 'Peran $nama diubah menjadi ${_labelRole(pilih)}.',
        sukses: err == null);
    await _muat();
  }

  Future<void> _hubungkanAnak(
      String id, String nama, String role) async {
    if (role != 'orang_tua') {
      _pesan('Relasi orang tua–siswa hanya untuk akun berperan Orang Tua. '
          'Ubah perannya lebih dahulu.');
      return;
    }

    final siswa = await Repos.listSiswa();
    if (!mounted) return;
    if (siswa.data.isEmpty) {
      _pesan('Belum ada akun siswa. Buat akun siswa lebih dahulu.');
      return;
    }

    String pilih = siswa.data.first['id']?.toString() ?? '';
    String hubungan = 'ayah';

    final lanjut = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Hubungkan $nama ke anak'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: pilih,
                decoration: const InputDecoration(labelText: 'Siswa'),
                items: [
                  for (final s in siswa.data)
                    DropdownMenuItem(
                      value: s['id']?.toString(),
                      child: Text(s['nama']?.toString() ?? '-'),
                    ),
                ],
                onChanged: (v) => setLocal(() => pilih = v ?? pilih),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: hubungan,
                decoration: const InputDecoration(labelText: 'Hubungan'),
                items: const [
                  DropdownMenuItem(value: 'ayah', child: Text('Ayah')),
                  DropdownMenuItem(value: 'ibu', child: Text('Ibu')),
                  DropdownMenuItem(value: 'wali', child: Text('Wali')),
                ],
                onChanged: (v) => setLocal(() => hubungan = v ?? hubungan),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Hubungkan')),
          ],
        ),
      ),
    );

    if (lanjut != true) return;
    final err = await Repos.adminSetRelasiOrtu(
        parentId: id, studentId: pilih, hubungan: hubungan);
    _pesan(err ?? 'Relasi $nama dengan siswa tersimpan.', sukses: err == null);
    await _muat();
  }
}

class _PilFilter extends StatelessWidget {
  const _PilFilter({
    required this.label,
    required this.aktif,
    required this.jumlah,
    required this.onTap,
  });

  final String label;
  final bool aktif;
  final int jumlah;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: aktif ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: aktif ? null : appSoftShadow,
        ),
        child: Text(
          '$label ($jumlah)',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
            color: aktif ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

/// Formulir pembuatan akun. Kata sandi awal WAJIB diketik admin (minimal 8
/// karakter) sehingga tidak ada kata sandi bawaan yang selalu sama.
class _FormBuatAkun extends StatefulWidget {
  const _FormBuatAkun({required this.kelas});
  final List<RowData> kelas;

  @override
  State<_FormBuatAkun> createState() => _FormBuatAkunState();
}

class _FormBuatAkunState extends State<_FormBuatAkun> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _nama = TextEditingController();
  final _identitas = TextEditingController();
  final _sandi = TextEditingController();
  String _role = 'siswa';
  String? _kelasId;
  bool _sibuk = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _nama.dispose();
    _identitas.dispose();
    _sandi.dispose();
    super.dispose();
  }

  String get _labelIdentitas => switch (_role) {
        'siswa' => 'NIS',
        'orang_tua' => 'Tidak perlu',
        _ => 'NIP / NUPTK',
      };

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _sibuk = true;
      _error = null;
    });

    final err = await Repos.adminCreateUser(
      email: _email.text.trim(),
      nama: _nama.text.trim(),
      role: _role,
      password: _sandi.text,
      identitas: _identitas.text.trim().isEmpty ? null : _identitas.text.trim(),
      kelasId: _role == 'siswa' ? _kelasId : null,
    );

    if (!mounted) return;
    setState(() => _sibuk = false);

    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Buat akun baru',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
                const SizedBox(height: 4),
                const Text(
                  'Akun langsung aktif. Sampaikan email dan kata sandi awal '
                  'kepada pengguna, lalu minta dia menggantinya.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Peran'),
                  items: const [
                    DropdownMenuItem(value: 'siswa', child: Text('Siswa')),
                    DropdownMenuItem(value: 'guru', child: Text('Guru')),
                    DropdownMenuItem(
                        value: 'guru_pembimbing', child: Text('Guru Pembimbing')),
                    DropdownMenuItem(value: 'orang_tua', child: Text('Orang Tua')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) => setState(() {
                    _role = v ?? _role;
                    if (_role != 'siswa') _kelasId = null;
                  }),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nama,
                  decoration: const InputDecoration(labelText: 'Nama lengkap'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nama wajib diisi.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return 'Email wajib diisi.';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
                      return 'Format email tidak valid.';
                    }
                    return null;
                  },
                ),
                if (_role != 'orang_tua') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _identitas,
                    decoration: InputDecoration(labelText: _labelIdentitas),
                    validator: (v) {
                      if (_role == 'siswa' && (v == null || v.trim().isEmpty)) {
                        return 'NIS wajib diisi untuk siswa.';
                      }
                      return null;
                    },
                  ),
                ],
                if (_role == 'siswa' && widget.kelas.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _kelasId,
                    decoration: const InputDecoration(labelText: 'Kelas'),
                    items: [
                      for (final k in widget.kelas)
                        DropdownMenuItem(
                          value: k['id']?.toString(),
                          child: Text(k['nama']?.toString() ?? '-'),
                        ),
                    ],
                    onChanged: (v) => setState(() => _kelasId = v),
                  ),
                ],
                if (_role == 'siswa' && widget.kelas.isEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Belum ada kelas. Siswa tetap bisa dibuat, kelas diatur '
                    'kemudian lewat menu Akademik.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.warning),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sandi,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Kata sandi awal (minimal 8 karakter)',
                  ),
                  validator: (v) => (v == null || v.length < 8)
                      ? 'Minimal 8 karakter.'
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(_error!,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.danger)),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _sibuk ? null : _simpan,
                  child: _sibuk
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white))
                      : const Text('Buat akun'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
