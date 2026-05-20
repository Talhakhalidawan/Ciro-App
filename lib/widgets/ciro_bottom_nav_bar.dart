import 'package:flutter/material.dart';
import '../utils/ciro_theme.dart';

/// Shared bottom navigation bar used across all screens in the Ciro app.
///
/// [currentIndex] – the currently active tab (0 = Home, 1 = Community, 2 = Crisis).
/// [onTabChanged] – callback when a tab is tapped.
/// [showCrisisTab] – whether the crisis tab should be visible.
/// [isCrisisActive] – whether the user is currently viewing the crisis page.
/// [onSyncTapped] – callback for the sync/diagnostics button.
/// [isSyncing] – whether a backend request is in progress.
class CiroBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;
  final bool showCrisisTab;
  final VoidCallback? onSyncTapped;
  final bool isSyncing;

  const CiroBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabChanged,
    this.showCrisisTab = false,
    this.onSyncTapped,
    this.isSyncing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      decoration: BoxDecoration(
        color: CiroTheme.navBarBackground,
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.06), width: 1.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            index: 0,
            activeIcon: Icons.home_rounded,
            inactiveIcon: Icons.home_outlined,
            label: 'Home',
            color: CiroTheme.primary,
          ),
          _buildNavItem(
            index: 1,
            activeIcon: Icons.people_rounded,
            inactiveIcon: Icons.people_outline_rounded,
            label: 'Community',
            color: CiroTheme.primary,
          ),

          // Sync / Weather Update Button
          _buildSyncButton(),

          if (showCrisisTab)
            _buildCrisisItem(),
        ],
      ),
    );
  }

  // ── Regular tab item ─────────────────────────────────────────────

  Widget _buildNavItem({
    required int index,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String label,
    required Color color,
  }) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTabChanged(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? color : Colors.black54,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Sync / Diagnostics Button ────────────────────────────────────

  Widget _buildSyncButton() {
    return GestureDetector(
      onTap: onSyncTapped,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSyncing ? CiroTheme.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: isSyncing
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(CiroTheme.primary),
                ),
              )
            : const Icon(
                Icons.sync_rounded,
                color: Colors.black54,
                size: 24,
              ),
      ),
    );
  }

  // ── Crisis tab item ──────────────────────────────────────────────

  Widget _buildCrisisItem() {
    final isSelected = currentIndex == 2;
    const crisisColor = CiroTheme.crisisRed;

    return GestureDetector(
      onTap: () => onTabChanged(2),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          // Red bg tint always visible, stronger when selected
          color: isSelected
              ? crisisColor.withValues(alpha: 0.15)
              : crisisColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          // No border/stroke per user request
        ),
        child: Row(
          children: [
            Icon(
              // Filled only when on the crisis page
              isSelected ? Icons.warning_rounded : Icons.warning_amber_rounded,
              // Icon color: red only when selected, neutral otherwise
              color: isSelected ? crisisColor : Colors.black54,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Crisis',
              style: TextStyle(
                color: isSelected ? crisisColor : Colors.black54,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
