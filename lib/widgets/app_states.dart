import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// Komponen state: loading, error, dan empty yang konsisten.
class AppStates {
  /// Skeleton loading untuk daftar.
  static Widget loading({int rows = 4}) {
    return Column(
      children: [
        for (var i = 0; i < rows; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SkeletonRow(),
          ),
      ],
    );
  }

  static Widget empty({
    required String title,
    String? message,
    IconData? icon,
    Widget? action,
  }) {
    return EmptyState(
      title: title,
      message: message,
      icon: icon ?? Icons.inbox_outlined,
      action: action,
    );
  }

  static Widget error({required String message, VoidCallback? onRetry}) {
    return ErrorState(message: message, onRetry: onRetry);
  }

  /// Indikator status backend (menampilkan saat backend belum terhubung).
  static Widget backendUnavailable({String? detail}) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.link_off, size: 20, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Backend belum terhubung',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(
                  detail ??
                      'Data yang ditampilkan berasal dari server. '
                          'Konfigurasi SUPABASE_ANON_KEY untuk melanjutkan.',
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Banner backend tidak tersedia (const).
  }

/// Banner backend tidak tersedia (const).
class AppStatesBackendUnavailableBanner extends StatelessWidget {
  const AppStatesBackendUnavailableBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.link_off, size: 20, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Backend belum terhubung',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Konfigurasi SUPABASE_ANON_KEY untuk melanjutkan. '
                  'Login hanya aktif setelah backend tersedia.',
                  style: TextStyle(
                      fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state yang bisa dipakai sebagai const.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    super.key,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state yang bisa dipakai sebagai const.
class ErrorState extends StatelessWidget {
  const ErrorState({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_outlined,
                  size: 32, color: AppColors.danger),
            ),
            const SizedBox(height: 16),
            const Text(
              'Terjadi gangguan',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Coba Lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton baris untuk daftar.
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({super.key, this.trailing = true});
  final bool trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _SkeletonBox(width: 44, height: 44, shape: BoxShape.circle),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SkeletonBox(width: 140, height: 12),
              const SizedBox(height: 8),
              const _SkeletonBox(width: 90, height: 10),
            ],
          ),
        ),
        if (trailing) const _SkeletonBox(width: 56, height: 22),
      ],
    );
  }
}

class _SkeletonBox extends StatefulWidget {
  const _SkeletonBox({required this.width, required this.height, this.shape});
  final double width;
  final double height;
  final BoxShape? shape;

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_controller),
      child: Container(
        width: widget.shape == BoxShape.circle ? widget.height : widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.border.withValues(alpha: 0.8),
          borderRadius:
              widget.shape == null ? BorderRadius.circular(6) : null,
          shape: widget.shape ?? BoxShape.rectangle,
        ),
      ),
    );
  }
}

/// Kartu statistik dengan label, nilai, ikon, dan aksen warna.
class StatCard extends StatelessWidget {
  const StatCard({
    required this.title,
    required this.value,
    this.trend,
    this.icon = Icons.insights_outlined,
    this.color = AppColors.primary,
    super.key,
  });

  final String title;
  final String value;
  final String? trend;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          if (trend != null) ...[
            const SizedBox(height: 4),
            Text(
              trend!,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: trend!.contains('+')
                    ? AppColors.success
                    : AppColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Badge status berwarna (berhasil, menunggu, gagal, dsb.).
class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.label, required this.state, super.key});
  final String label;
  final BadgeState state;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (state) {
      BadgeState.success => (
          AppColors.success.withValues(alpha: 0.14),
          AppColors.success
        ),
      BadgeState.warning => (
          AppColors.warning.withValues(alpha: 0.16),
          AppColors.warning
        ),
      BadgeState.danger => (
          AppColors.danger.withValues(alpha: 0.12),
          AppColors.danger
        ),
      BadgeState.info => (
          AppColors.primary.withValues(alpha: 0.12),
          AppColors.primary
        ),
      BadgeState.neutral => (
          AppColors.border,
          AppColors.textSecondary
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

enum BadgeState { success, warning, danger, info, neutral }

/// Avatar inisial untuk pengguna.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({
    required this.name,
    this.size = 40,
    super.key,
  });
  final String name;
  final double size;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColors.primary,
      AppColors.purple,
      AppColors.success,
      AppColors.warning,
      const Color(0xFF0E7FA8),
    ];
    final color = colors[name.length % colors.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

/// Helper salin ke clipboard dengan feedback.
void copyToClipboard(BuildContext context, String text, String label) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text('$label disalin ke clipboard.'),
      duration: const Duration(seconds: 2),
    ));
}
