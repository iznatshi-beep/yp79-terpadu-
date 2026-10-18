import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../services/repositories.dart';
import '../../../widgets/app_states.dart';
import '../../../widgets/common.dart';

/// Halaman Perpustakaan: katalog buku + e-book.
class PagePerpus extends StatefulWidget {
  const PagePerpus({super.key});

  @override
  State<PagePerpus> createState() => _PagePerpusState();
}

class _PagePerpusState extends State<PagePerpus> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _TabPill(
                label: 'Katalog Buku',
                active: _tab == 0,
                onTap: () => setState(() => _tab = 0),
              ),
              const SizedBox(width: 8),
              _TabPill(
                label: 'E-Book',
                active: _tab == 1,
                onTap: () => setState(() => _tab = 1),
              ),
            ],
          ),
        ),
        Expanded(
          child: _tab == 0 ? _KatalogBuku() : _EBookList(),
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

class _KatalogBuku extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QueryResult<Map<String, dynamic>>>(
      future: Repos.libraryBooks(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: SkeletonRow(),
          );
        }
        final books = snap.data?.data ?? const [];
        if (books.isEmpty) {
          return const EmptyState(
            title: 'Belum ada buku',
            message: 'Katalog perpustakaan akan tampil di sini.',
            icon: Icons.library_books_outlined,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: books.length,
          itemBuilder: (context, i) {
            final b = books[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.book_outlined,
                        color: AppColors.purple, size: 20),
                  ),
                  title: Text(
                    b['judul']?.toString() ?? '-',
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    [
                      b['penulis']?.toString() ?? '',
                      b['tahun_terbit']?.toString() ?? '',
                    ].join(' · '),
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                  trailing: StatusBadge(
                    label:
                        '${b['stok_tersedia'] ?? 0}/${b['stok_total'] ?? 0}',
                    state: (b['stok_tersedia'] as num? ?? 0) > 0
                        ? BadgeState.success
                        : BadgeState.danger,
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

class _EBookList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QueryResult<Map<String, dynamic>>>(
      future: Repos.digitalResources(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: SkeletonRow(),
          );
        }
        final items = snap.data?.data ?? const [];
        if (items.isEmpty) {
          return const EmptyState(
            title: 'Belum ada e-book',
            message: 'Materi digital perpustakaan akan tampil di sini.',
            icon: Icons.tablet_outlined,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final d = items[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.picture_as_pdf_outlined,
                        color: AppColors.primary, size: 20),
                  ),
                  title: Text(
                    d['judul']?.toString() ?? '-',
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    d['kategori']?.toString() ?? '',
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 18,
                      color: AppColors.textSecondary),
                  onTap: () {
                    if (d['file_url'] != null) {
                      showToast(
                          context, 'Membuka e-book: ${d['judul']}');
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
