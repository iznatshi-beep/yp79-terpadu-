import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../services/repositories.dart';
import '../../../widgets/app_states.dart';

/// Halaman Komunikasi: pengumuman + chat.
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
          padding: const EdgeInsets.all(18),
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
        Expanded(child: _tab == 0 ? _AnnouncementList() : _ChatList()),
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
          color: active ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _AnnouncementList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QueryResult<Map<String, dynamic>>>(
      future: Repos.announcements(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: SkeletonRow(),
          );
        }
        final anns = snap.data?.data ?? const [];
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
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  title: Text(
                    a['judul']?.toString() ?? '-',
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    a['isi']?.toString() ?? '',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  leading: StatusBadge(label: badge.$2, state: badge.$1),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ChatList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QueryResult<Map<String, dynamic>>>(
      future: Repos.conversations(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: SkeletonRow(),
          );
        }
        final convs = snap.data?.data ?? const [];
        if (convs.isEmpty) {
          return const EmptyState(
            title: 'Belum ada percakapan',
            message: 'Chat internal akan tampil di sini.',
            icon: Icons.forum_outlined,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(18),
          itemCount: convs.length,
          itemBuilder: (context, i) {
            final c = convs[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.purple.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat_bubble_outline,
                        color: AppColors.purple, size: 20),
                  ),
                  title: Text(
                    (c['nama_pembuat']?.toString() ?? 'Percakapan').isEmpty
                        ? 'Percakapan'
                        : c['nama_pembuat'].toString(),
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    c['created_at']?.toString().split('T')[0] ?? '',
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
