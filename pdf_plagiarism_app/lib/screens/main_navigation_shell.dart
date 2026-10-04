import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'batch_evaluation_screen.dart';
import 'profile_screen.dart';
import 'results_screen.dart';
import 'upload_screen.dart';

/// Top-level shell hosting persistent bottom navigation.
/// Displays 4 tabs for Admin / Instructors (Dashboard, Batch Lab, Similarity, Profile)
/// and 2 tabs for Students (My Submissions, Profile).
class MainNavigationShell extends StatefulWidget {
  final int initialIndex;

  const MainNavigationShell({super.key, this.initialIndex = 0});

  static void switchTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_MainNavigationShellState>();
    state?.setTab(index);
  }

  static void goToProfile(BuildContext context) {
    final state = context.findAncestorStateOfType<_MainNavigationShellState>();
    state?.goToProfile();
  }

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void setTab(int index) {
    final appState = context.read<AppState>();
    final maxIndex = appState.isAdmin ? 3 : 1;
    // Map requests for profile (e.g. index 3) to index 1 for students
    int target = index;
    if (!appState.isAdmin && target > 1) {
      target = 1;
    }
    target = target.clamp(0, maxIndex);

    if (target == 2 && appState.results.isEmpty) {
      appState.reloadSavedResults();
    }

    if (_currentIndex != target) {
      setState(() => _currentIndex = target);
    }
  }

  void goToProfile() {
    final appState = context.read<AppState>();
    setTab(appState.isAdmin ? 3 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isAdmin = appState.isAdmin;
    final flaggedCount = appState.results.where((r) => r.isFlagged).length;
    final resultsCount = appState.results.length;
    final similarityBadge = flaggedCount > 0
        ? flaggedCount
        : (resultsCount > 0 ? resultsCount : null);
    final similarityBadgeColor = flaggedCount > 0 ? AppColors.high : AppColors.brand;
    final unreadCount = appState.unreadNotifications.length;

    // Pages dynamically scoped to user role
    final pages = isAdmin
        ? const [
            UploadScreen(),
            BatchEvaluationScreen(),
            ResultsScreen(),
            ProfileScreen(),
          ]
        : const [
            UploadScreen(),
            ProfileScreen(),
          ];

    // Ensure _currentIndex is within valid bounds if role changed
    final safeIndex = _currentIndex.clamp(0, pages.length - 1);
    if (safeIndex != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentIndex = safeIndex);
      });
    }

    return Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: AppColors.line, width: 1.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: isAdmin
                  ? [
                      Expanded(
                        child: _NavBarItem(
                          icon: Icons.dashboard_outlined,
                          activeIcon: Icons.dashboard_rounded,
                          label: 'Dashboard',
                          isSelected: safeIndex == 0,
                          onTap: () => setTab(0),
                        ),
                      ),
                      Expanded(
                        child: _NavBarItem(
                          icon: Icons.hub_outlined,
                          activeIcon: Icons.hub_rounded,
                          label: 'Batch Lab',
                          isSelected: safeIndex == 1,
                          onTap: () => setTab(1),
                        ),
                      ),
                      Expanded(
                        child: _NavBarItem(
                          icon: Icons.compare_arrows_rounded,
                          activeIcon: Icons.compare_arrows_rounded,
                          label: 'Similarity',
                          isSelected: safeIndex == 2,
                          badgeCount: similarityBadge,
                          badgeColor: similarityBadgeColor,
                          onTap: () => setTab(2),
                        ),
                      ),
                      Expanded(
                        child: _NavBarItem(
                          icon: Icons.person_outline_rounded,
                          activeIcon: Icons.person_rounded,
                          label: 'Profile',
                          isSelected: safeIndex == 3,
                          badgeCount: unreadCount > 0 ? unreadCount : null,
                          onTap: () => setTab(3),
                        ),
                      ),
                    ]
                  : [
                      Expanded(
                        child: _NavBarItem(
                          icon: Icons.assignment_outlined,
                          activeIcon: Icons.assignment_rounded,
                          label: 'My Submissions',
                          isSelected: safeIndex == 0,
                          onTap: () => setTab(0),
                        ),
                      ),
                      Expanded(
                        child: _NavBarItem(
                          icon: Icons.person_outline_rounded,
                          activeIcon: Icons.person_rounded,
                          label: 'Profile',
                          isSelected: safeIndex == 1,
                          badgeCount: unreadCount > 0 ? unreadCount : null,
                          onTap: () => setTab(1),
                        ),
                      ),
                    ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int? badgeCount;
  final Color? badgeColor;

  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isSelected ? AppColors.brand : AppColors.muted;
    final textColor = isSelected ? AppColors.brand : AppColors.muted;

    Widget iconWidget = Icon(
      isSelected ? activeIcon : icon,
      size: 21,
      color: iconColor,
    );

    if (badgeCount != null && badgeCount! > 0) {
      iconWidget = Badge(
        label: Text(
          badgeCount! > 99 ? '99+' : '$badgeCount',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        backgroundColor: badgeColor ?? AppColors.high,
        child: iconWidget,
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.mint.withValues(alpha: 0.22)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: iconWidget,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: textColor,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
