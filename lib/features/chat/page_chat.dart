import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../services/repositories.dart';
import '../../../widgets/app_states.dart';
import '../../../widgets/common.dart';
import 'chat_thread_page.dart';

/// Halaman Komunikasi: pengumuman + chat.
///
/// Perbaikan audit pada halaman ini:
///  - daftar chat sebelumnya membaca kolom `nama_pembuat` yang TIDAK ADA di
///    schema, sehingga judul percakapan selalu "Percakapan" (tidak informatif);
///    sekarang nama lawan bicara diambil lewat RPC `conversation_peers`;
///  - percakapan tidak bisa dibuka & tidak bisa dibuat sama sekali dari app;
///    sekarang tap = buka thread (baca + kirim) dan ada tombol "Mulai chat"
///    yang memilih guru lalu memanggil RPC `start_conversation`.
class PageChat extends StatefulWidget {
  const PageChat({super.key});

  @override
  State<PageChat> createState() => _PageChatState();
}

class _PageChatState extends State<PageChat> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
          child: Row(
            children: [
              _TabPill(
                label: 'Pengumuman',
                active: _tab == 0,
                onTap: () => setState(() => _tab = 0),
              ),
              const SizedBox(width: 8),
              _TabPill(
                label: 'Pesan',
                active: _tab == 1,
                onTap: () => setState(() => _tab = 1),
              ),
            ],
          ),
        ),
        Expanded(
          child: _tab == 0
              ? const _AnnouncementList()
              : const _ChatList(),
        ),
      ],
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.primaryBg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? Colors.white : AppColors.primaryDark,
          ),
        ),
      ),
    );
  }
}

class _AnnouncementList extends StatelessWidget {
  const _AnnouncementList();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QueryResult<RowData>>(
      future: Repos.announcements(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(18),
            child: SkeletonRow(),
          );
        }
        if (snap.data?.error != null) {
          return ErrorState(message: snap.data!.error!);
        }
        final anns = snap.data?.data ?? const <RowData>[];
        if (anns.isEmpty) {
          return const EmptyState(
            title: 'Belum ada pengumuman',
            message: 'Pengumuman sekolah akan tampil di sini.',
            icon: Icons.campaign_outlined,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(18),
          itemCount: anns.length,
          itemBuilder: (context, i) {
            final a = anns[i];
            final prioritas = a['prioritas']?.toString() ?? 'biasa';
            final badge = switch (prioritas) {
              'darurat' => (BadgeState.danger, 'Darurat'),
              'penting' => (BadgeState.warning, 'Penting'),
              _ => (BadgeState.info, 'Biasa'),
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  boxShadow: appSoftShadow,
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusBadge(label: badge.$2, state: badge.$1),
                        const Spacer(),
                        Text(
                          a['dipublikasikan_pada']
                                  ?.toString()
                                  .split('T')
                                  .first ??
                              '',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      a['judul']?.toString() ?? '-',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink),
                    ),
                    if ((a['isi']?.toString() ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        a['isi'].toString(),
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.muted),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ChatList extends StatefulWidget {
  const _ChatList({super.key});

  @override
  State<_ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<_ChatList> {
  bool _loading = true;
  String? _error;
  List<RowData> _convs = const [];
  Map<String, String> _namaOrang = const {};
  bool _mulai = false;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _loading = _convs.isEmpty;
      _error = null;
    });

    final conv = await Repos.conversations();
    final peers = await Repos.conversationPeers();
    if (!mounted) return;

    // Ibu jari: peta userId -> nama, supaya judul chat tidak lagi "-".
    final peta = <String, String>{};
    for (final p in peers.data) {
      final id = p['user_id']?.toString();
      final nama = p['nama']?.toString();
      if (id != null && nama != null) peta[id] = nama;
    }

    setState(() {
      _convs = conv.data;
      _peers = peers.data;
      _namaOrang = peta;
      _error = conv.error ?? peers.error;
      _loading = false;
    });
  }

  /// Judul percakapan = nama peserta lain (bukan diri sendiri).
  String _judul(RowData c) {
    final id = c['id']?.toString() ?? '';
    final saya = Repos.uid;
    final nama = <String>[];
    for (final p in _peerRows(id)) {
      final uid = p['user_id']?.toString();
      if (uid == null || uid == saya) continue;
      nama.add(p['nama']?.toString() ?? '');
    }
    if (nama.isNotEmpty) return nama.join(', ');
    // cadangan: pakai guru/pembuat
    final g = c['guru_user_id']?.toString();
    final d = c['dibuat_oleh']?.toString();
    final ganti = [g, d].whereType<String>().where((x) => x != saya).toList();
    for (final x in ganti) {
      final n = _namaOrang[x];
      if (n != null) return n;
    }
    return 'Percakapan';
  }

  List<RowData> _peers = const [];

  List<RowData> _peerRows(String convId) => [
        for (final p in _peers)
          if (p['conversation_id']?.toString() == convId) p
      ];

  Future<void> _mulaiChat() async {
    final guru = await Repos.listGuru();
    if (!mounted) return;
    if (!guru.ok || guru.data.isEmpty) {
      showToast(
        context,
        'Belum ada akun guru yang bisa dihubungi. Hubungi admin sekolah.',
        color: AppColors.warning,
      );
      return;
    }

    String? pilih = guru.data.first['user_id']?.toString();
    final lanjut = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mulai percakapan'),
        content: DropdownButtonFormField<String>(
          initialValue: pilih,
          decoration: const InputDecoration(labelText: 'Guru tujuan'),
          items: [
            for (final g in guru.data)
              DropdownMenuItem(
                value: g['user_id']?.toString(),
                child: Text(g['nama']?.toString() ?? '-'),
              ),
          ],
          onChanged: (v) => pilih = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mulai'),
          ),
        ],
      ),
    );
    if (lanjut != true || pilih == null || !mounted) return;

    setState(() => _mulai = true);
    final convId = await Repos.startConversation(pilih!);
    if (!mounted) return;
    setState(() => _mulai = false);

    if (convId == null || convId.isEmpty) {
      showToast(context, 'Gagal membuat percakapan.', color: AppColors.danger);
      return;
    }
    await _buka(convId, _namaOrang[pilih!] ?? 'Percakapan');
  }

  Future<void> _buka(String conversationId, String judul) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatThreadPage(
          conversationId: conversationId,
          judul: judul,
        ),
      ),
    );
    if (mounted) await _muat();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _body(),
        Positioned(
          right: 18,
          bottom: 18,
          child: FloatingActionButton.extended(
            onPressed: _mulai ? null : _mulaiChat,
            icon: const Icon(Icons.add_comment_outlined, size: 20),
            label: const Text('Mulai chat'),
          ),
        ),
      ],
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: SkeletonRow(),
      );
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _muat);
    }
    if (_convs.isEmpty) {
      return const EmptyState(
        title: 'Belum ada percakapan',
        message: 'Tekan "Mulai chat" untuk menghubungi guru.',
        icon: Icons.forum_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 90),
        itemCount: _convs.length,
        itemBuilder: (context, i) {
          final c = _convs[i];
          final id = c['id']?.toString() ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.card),
              onTap: () => _buka(id, _judul(c)),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  boxShadow: appSoftShadow,
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.purpleBg,
                        borderRadius: BorderRadius.circular(AppRadius.tile),
                      ),
                      child: const Icon(Icons.chat_bubble_outline,
                          color: AppColors.purple, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _judul(c),
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            c['created_at']?.toString().split('T').first ?? '',
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.muted),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
