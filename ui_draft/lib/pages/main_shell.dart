import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app_theme.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    _TabItem(path: '/feed', label: 'Feed', icon: Icons.grid_view_rounded, activeIcon: Icons.grid_view_rounded),
    _TabItem(path: '/explore', label: 'Explore', icon: Icons.language_outlined, activeIcon: Icons.language),
    _TabItem(path: '/volunteer', label: 'Volunteer', icon: Icons.favorite_outline, activeIcon: Icons.favorite),
    _TabItem(path: '/saved', label: 'Saved', icon: Icons.bookmark_outline, activeIcon: Icons.bookmark),
    _TabItem(path: '/profile', label: 'You', icon: Icons.person_outline, activeIcon: Icons.person),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);

    return Scaffold(
      backgroundColor: AppColors.ground,
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.canvas.withOpacity(0.96),
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final isActive = i == currentIndex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => context.go(tab.path),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isActive ? tab.activeIcon : tab.icon,
                            size: 22,
                            color: isActive ? AppColors.forest : AppColors.inkMuted,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                              color: isActive ? AppColors.forest : AppColors.inkMuted,
                              fontFamily: 'Outfit',
                            ),
                          ),
                          const SizedBox(height: 2),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: isActive ? 16 : 0,
                            height: 3,
                            decoration: BoxDecoration(
                              color: AppColors.forest,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final String path;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _TabItem({required this.path, required this.label, required this.icon, required this.activeIcon});
}
