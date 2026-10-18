import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../services/repositories.dart';
import '../../../widgets/app_states.dart';
import '../../../widgets/common.dart';

/// Isi satu percakapan: daftar pesan + kirim pesan.
///
/// Sebelumnya `Repos.messages()` dan `Repos.sendMessage()` tidak dipanggil layar
/// mana pun — daftar chat bisa dilihat tetapi isinya tidak pernah bisa dibuka
/// atau dikirim. Catatan jujur: pengambilan pesan di sini memakai tombol
/// "Muat ulang" + tarik-untuk-refresh, BUKAN realtime; Supabase Realtime belum
/// diaktifkan sehingga tidak ada klaim pesan "langsung masuk".
class ChatThreadPage extends StatefulWidget {
  const ChatThreadPage({
    super.key,
    required this.conversationId,
    required this.judul,
  });

  final String conversationId;
  final String judul;

  @override
  State<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends State<ChatThreadPage> {
  final _pesanCtrl = TextEditingController();
  final _scroll = ScrollController();
  bool _loading = true;
  bool _mengirim = false;
  String? _error;
  List<RowData> _pesan = const [];

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _pesanCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() {
      _loading = _pesan.isEmpty;
      _error = null;
    });
    final res = await Repos.messages(widget.conversationId);
    if (!mounted) return;
    setState(() {
      _pesan = res.data;
      _error = res.error;
      _loading = false;
    });
    // Gulir ke pesan terbaru (pesan diurutkan naik oleh server).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _kirim() async {
    final teks = _pesanCtrl.text.trim();
    if (teks.isEmpty) return;
    setState(() => _mengirim = true);
    final ok = await Repos.sendMessage(
      conversationId: widget.conversationId,
      isi: teks,
    );
    if (!mounted) return;
    setState(() => _mengirim = false);

    if (ok) {
      _pesanCtrl.clear();
      await _muat();
    } else {
      showToast(
        context,
        'Pesan gagal terkirim — Anda mungkin tidak terdaftar di percakapan ini.',
        color: AppColors.danger,
      );
    }
  }

  String _jam(String? iso) {
    if (iso == null) return '';
    final t = DateTime.tryParse(iso);
    if (t == null) return iso.split('T').first;
    final lokal = t.toLocal();
    final d = lokal.day.toString().padLeft(2, '0');
    final m = lokal.month.toString().padLeft(2, '0');
    final h = lokal.hour.toString().padLeft(2, '0');
    final mi = lokal.minute.toString().padLeft(2, '0');
    return '$d/$m $h:$mi';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.judul, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _muat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _body()),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pesanCtrl,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _kirim(),
                      decoration: const InputDecoration(
                        hintText: 'Tulis pesan...',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _mengirim ? null : _kirim,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    child: _mengirim
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
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
    if (_pesan.isEmpty) {
      return const EmptyState(
        title: 'Belum ada pesan',
        message: 'Kirim pesan pertama pada percakapan ini.',
        icon: Icons.chat_bubble_outline,
      );
    }
    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(18),
        itemCount: _pesan.length,
        itemBuilder: (context, i) {
          final p = _pesan[i];
          final milikSaya = (p['pengirim_user_id']?.toString() ?? '') == Repos.uid;
          return Align(
            alignment:
                milikSaya ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: milikSaya ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.md),
                  topRight: const Radius.circular(AppRadius.md),
                  bottomLeft: Radius.circular(milikSaya ? AppRadius.md : 2),
                  bottomRight: Radius.circular(milikSaya ? 2 : AppRadius.md),
                ),
                border: Border.all(
                  color: milikSaya ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p['isi']?.toString() ?? '',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: milikSaya ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _jam(p['created_at']?.toString()),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: milikSaya
                          ? Colors.white70
                          : AppColors.textSecondary,
                    ),
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
