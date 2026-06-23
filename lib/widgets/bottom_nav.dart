import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import 'status_bar.dart';

/// Bottom navigation bar reused across Dashboard / History / Report / Setting.
/// Per Figma 1:578: filled background #F7F7F7, 62px high, single active item
/// shown in deep brand-green (#133E16).
enum NavTab { dashboard, history, report, setting }

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.active});

  final NavTab active;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F7F7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 62,
            child: Row(
              children: [
                _NavItem(
                  label: 'Dashboard',
                  icon: Icons.home_rounded,
                  active: active == NavTab.dashboard,
                  onTap: () => _goto(context, AppRoutes.home),
                ),
                _NavItem(
                  label: 'History',
                  icon: Icons.history_rounded,
                  active: active == NavTab.history,
                  onTap: () => _goto(context, AppRoutes.history),
                ),
                _NavItem(
                  label: 'Report',
                  icon: Icons.description_outlined,
                  active: active == NavTab.report,
                  onTap: () => _goto(context, AppRoutes.reports),
                ),
                _NavItem(
                  label: 'Setting',
                  icon: Icons.settings_outlined,
                  active: active == NavTab.setting,
                  onTap: () => _goto(context, AppRoutes.settings),
                ),
              ],
            ),
          ),
          const NotchArea(),
        ],
      ),
    );
  }

  void _goto(BuildContext context, String route) {
    final nav = Navigator.of(context);
    if (ModalRoute.of(context)?.settings.name == route) return;
    // Dashboard is the persistent root. Tapping it drops any sub-tab on top;
    // tapping another tab resets to the root first, then stacks that tab — so
    // the hardware/UI Back button always returns to Dashboard rather than
    // exiting the app. Anchoring to isFirst works whether the root arrived as
    // "/" (AuthGate) or "/home" (after a fresh login).
    nav.popUntil((r) => r.isFirst);
    if (route != AppRoutes.home) {
      nav.pushNamed(route);
    }
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF133E16) : const Color(0xFF767676);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: active ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
