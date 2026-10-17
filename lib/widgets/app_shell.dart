import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Shell layar utama per role: header + bottom navigation.
class AppShell extends StatefulWidget {
  const AppShell({
    required this.title,
    required this.body,
    required this.bottomNav,
    super.key,
    this.actions,
  });

  final String title;
  final Widget body;
  final List<BottomNavItem> bottomNav;
  final List<Widget>? actions;

  @override
  State<AppShell> createState() => _AppShellState();
}

class BottomNavItem {
  const BottomNavItem({
    required this.id,
    required this.label,
    required this.icon,
    this.iconSelected,
  });
  final String id;
  final String label;
  final IconData icon;
  final IconData? iconSelected;
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final item = widget.bottomNav[_index];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (widget.actions != null) ...widget.actions!,
          ],
        ),
        bottom: PreferredTweenTabBar(item: item),
      ),
      body: widget.body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final n in widget.bottomNav)
            NavigationDestination(
              icon: Icon(n.icon),
              selectedIcon: n.iconSelected != null ? Icon(n.iconSelected!) : Icon(n.icon),
              label: n.label,
            ),
        ],
      ),
    );
  }
}

/// Wrapper tabbar (placeholder — NavigationBar menangani navigasi).
class PreferredTweenTabBar extends StatelessWidget {
  const PreferredTweenTabBar({required this.item, super.key});
  final BottomNavItem item;

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(0),
      child: Container(),
    );
  }
}
