import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Satu aksi/modul yang bisa dibuka dari dashboard.
class ModulAksi {
  const ModulAksi({
    required this.label,
    required this.icon,
    required this.builder,
    this.color,
  });

  final String label;
  final IconData icon;
  final WidgetBuilder builder;
  final Color? color;
}

/// Grid aksi cepat pada dashboard. Setiap tombol membuka halaman nyata
/// (bukan dekorasi) — sesuai aturan "tidak ada tombol tanpa fungsi".
class ModulAksiGrid extends StatelessWidget {
  const ModulAksiGrid({super.key, required this.items});

  final List<ModulAksi> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.92,
      children: [
        for (final a in items)
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: a.builder)),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                boxShadow: appSoftShadow,
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (a.color ?? AppColors.primary)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                    ),
                    child: Icon(a.icon,
                        size: 22, color: a.color ?? AppColors.primary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    a.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
