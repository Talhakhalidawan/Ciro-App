import 'package:flutter/material.dart';
import '../utils/ciro_theme.dart';

/// Shared bottom navigation bar used across all screens in the Ciro app.
///
/// Icon-only design for a clean, professional look.
/// Tabs: Home (0), Community (1), Crisis (2, conditional).
class CiroBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;
  final bool showCrisisTab;

  const CiroBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabChanged,
    this.showCrisisTab = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
      decoration: BoxDecoration(
        color: CiroTheme.navBarBackground,
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.05), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTab(
            index: 0,
            activeIcon: Icons.explore_rounded,
            inactiveIcon: Icons.explore_outlined,
            color: CiroTheme.primary,
          ),
          _buildTab(
            index: 1,
            activeIcon: Icons.groups_rounded,
            inactiveIcon: Icons.groups_outlined,
            color: CiroTheme.primary,
          ),
          if (showCrisisTab)
            _buildTab(
              index: 2,
              activeIcon: Icons.warning_rounded,
              inactiveIcon: Icons.warning_amber_rounded,
              color: CiroTheme.crisisRed,
              isCrisis: true,
            ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required int index,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required Color color,
    bool isCrisis = false,
  }) {
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () => onTabChanged(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isCrisis ? 0.12 : 0.1)
              : isCrisis
                  ? color.withValues(alpha: 0.06)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          isSelected ? activeIcon : inactiveIcon,
          color: isSelected ? color : Colors.grey.shade400,
          size: 26,
        ),
      ),
    );
  }
}
