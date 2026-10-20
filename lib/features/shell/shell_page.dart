import 'package:flutter/material.dart';

import '../../core/models/role.dart';
import '../../core/models/session_profile.dart';
import '../../core/theme.dart';
import '../../services/api.dart';
import '../../widgets/app_states.dart';
import '../../widgets/common.dart';
import '../akademik/akademik_page.dart';
import '../beranda/admin_dashboard.dart';
import '../beranda/guru_dashboard.dart';
import '../beranda/siswa_dashboard.dart';
import '../beranda/orang_tua_dashboard.dart';
import '../lms/lms_page.dart';
import '../cbt/cbt_page.dart';
import '../perpus/page_perpus.dart';
import '../keuangan/page_keuangan.dart';
import '../chat/page_chat.dart';
import '../mabit/page_mabit.dart';

/// Shell utama aplikasi per role: header profil + body per tab + bottom nav.
class ShellPage extends StatefulWidget {
  const ShellPage({super.key, required this.profile});
  final SessionProfile profile;

  @override
  State<ShellPage> createState() => _ShellPageState();
}

typedef TabBuilder = Widget Function({required SessionProfile profile});

class _TabDef {
  const _TabDef({
    required this.label,
    required this.icon,
    required this.builder,
  });
  final String label;
  final IconData icon;
  final TabBuilder builder;
}

class _ShellPageState extends State<ShellPage> {
  /// Id tab yang sudah pernah dibuka.
  ///
  /// `body` hanya menampilkan tab aktif. Namun, bila tab sudah pernah dibuka
  /// (ada di [_aktif]), widgetnya dipertahankan di dalam [IndexedStack]
  /// sehingga form/list tidak hilang saat pindah. Tab yang belum pernah
  /// dibuka tetap belum dibangun — tidak ada biaya render berlebih saat masuk
  /// aplikasi (penting: admin punya 8 tab).
  final Set<int> _aktif = {0};

  int _tab = 0;

  void _keTab(int i) {
    setState(() {
      _tab = i;
      _aktif.add(i);
    });
  }

  List<_TabDef> get _tabs {
    final role = widget.profile.role;
    if (role == Role.admin) {
      return [
        _TabDef(
          label: 'Beranda',
          icon: Icons.grid_view_rounded,
          builder: ({required profile}) =>
              AdminDashboard(profile: profile),
        ),
        _TabDef(
          label: 'Akademik',
          icon: Icons.school_outlined,
          builder: ({required profile}) => const AkademikPage(),
        ),
        _TabDef(
          label: 'LMS',
          icon: Icons.menu_book_outlined,
          builder: ({required profile}) => LmsPage(profile: profile),
        ),
        _TabDef(
          label: 'Ujian',
          icon: Icons.assignment_outlined,
          builder: ({required profile}) => const CbtPage(),
        ),
        _TabDef(
          label: 'Perpus',
          icon: Icons.library_books_outlined,
          builder: ({required profile}) => PagePerpus(profile: profile),
        ),
        _TabDef(
          label: 'Keuangan',
          icon: Icons.receipt_long_outlined,
          builder: ({required profile}) => const PageKeuangan(),
        ),
        _TabDef(
          label: 'MABIT',
          icon: Icons.stars_outlined,
          builder: ({required profile}) => PageMabit(profile: profile),
        ),
        _TabDef(
          label: 'Komunikasi',
          icon: Icons.forum_outlined,
          builder: ({required profile}) => const PageChat(),
        ),
      ];
    }
    if (role == Role.guru || role == Role.guruPembimbing) {
      return [
        _TabDef(
          label: 'Beranda',
          icon: Icons.grid_view_rounded,
          builder: ({required profile}) =>
              GuruDashboard(profile: profile),
        ),
        _TabDef(
          label: 'Akademik',
          icon: Icons.school_outlined,
          builder: ({required profile}) => const AkademikPage(),
        ),
        _TabDef(
          label: 'LMS',
          icon: Icons.menu_book_outlined,
          builder: ({required profile}) => LmsPage(profile: profile),
        ),
        _TabDef(
          label: 'Ujian',
          icon: Icons.assignment_outlined,
          builder: ({required profile}) => const CbtPage(),
        ),
        _TabDef(
          label: 'MABIT',
          icon: Icons.stars_outlined,
          builder: ({required profile}) => PageMabit(profile: profile),
        ),
        _TabDef(
          label: 'Komunikasi',
          icon: Icons.forum_outlined,
          builder: ({required profile}) => const PageChat(),
        ),
      ];
    }
    if (role == Role.siswa) {
      return [
        _TabDef(
          label: 'Beranda',
          icon: Icons.home_outlined,
          builder: ({required profile}) =>
              SiswaDashboard(profile: profile),
        ),
        _TabDef(
          label: 'LMS',
          icon: Icons.menu_book_outlined,
          builder: ({required profile}) => LmsPage(profile: profile),
        ),
        _TabDef(
          label: 'Ujian',
          icon: Icons.assignment_outlined,
          builder: ({required profile}) => const CbtPage(),
        ),
        _TabDef(
          label: 'Perpus',
          icon: Icons.library_books_outlined,
          builder: ({required profile}) => PagePerpus(profile: profile),
        ),
        _TabDef(
          label: 'MABIT',
          icon: Icons.stars_outlined,
          builder: ({required profile}) => PageMabit(profile: profile),
        ),
      ];
    }
    // orang tua
    return [
      _TabDef(
        label: 'Beranda',
        icon: Icons.home_outlined,
        builder: ({required profile}) =>
            OrangTuaDashboard(profile: profile),
      ),
      _TabDef(
        label: 'Akademik',
        icon: Icons.school_outlined,
        builder: ({required profile}) => const AkademikPage(),
      ),
      _TabDef(
        label: 'Keuangan',
        icon: Icons.receipt_long_outlined,
        builder: ({required profile}) => const PageKeuangan(),
      ),
      _TabDef(
        label: 'MABIT',
        icon: Icons.stars_outlined,
        builder: ({required profile}) => PageMabit(profile: profile),
      ),
      _TabDef(
        label: 'Komunikasi',
        icon: Icons.forum_outlined,
        builder: ({required profile}) => const PageChat(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    if (_tab >= tabs.length) _tab = 0;
    final tab = tabs[_tab];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            InitialAvatar(
              name: widget.profile.name ?? widget.profile.role.label,
              size: 36,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.profile.name ?? widget.profile.role.label,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    tab.label,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout, size: 20),
            onPressed: () async {
              final ok = await showConfirmDialog(
                context,
                judul: 'Keluar aplikasi?',
                pesan: 'Sesi Anda akan diakhiri.',
                tombolYa: 'Keluar',
              );
              if (ok) await Api.logout();
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          for (var i = 0; i < tabs.length; i++)
            if (_aktif.contains(i))
              tabs[i].builder(profile: widget.profile)
            else
              const SizedBox.shrink(),
        ],
      ),
      // Navigasi bawah ala showcase: putih, sudut atas 24, label tampil.
      // Bila tab > 5 (mis. admin 8 tab), label hanya muncul pada tab terpilih
      // agar tidak berdesakan — showcase-nya sendiri hanya 5 slot.
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: appSoftShadow,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: NavigationBar(
            selectedIndex: _tab,
            labelBehavior: tabs.length > 5
                ? NavigationDestinationLabelBehavior.onlyShowSelected
                : NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: _keTab,
            destinations: [
              for (final t in tabs)
                NavigationDestination(
                  icon: Icon(t.icon),
                  selectedIcon: Icon(t.icon, size: 22),
                  label: t.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
