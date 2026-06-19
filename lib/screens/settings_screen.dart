import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../services/settings_store.dart';
import '../services/zone_store.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/page_header.dart';
import '../widgets/status_bar.dart';

/// SETTINGS — Figma node 1:798. Sliders + activation-mode radios + toggles,
/// all backed by [SettingsStore].
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const FakeStatusBar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: PageHeader(
                title: 'Settings',
                onBack: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacementNamed(context, AppRoutes.home);
                  }
                },
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<AppSettings>(
                valueListenable: SettingsStore.instance.settings,
                builder: (context, s, _) => _Form(settings: s),
              ),
            ),
            const AppBottomNav(active: NavTab.setting),
          ],
        ),
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final store = SettingsStore.instance;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ThresholdSlider(
            label: 'Temperature',
            value: settings.tempThreshold.clamp(0, 50),
            min: 0,
            max: 50,
            unit: '°C',
            iconBg: const Color(0xFFFFF7ED),
            iconColor: const Color(0xFFFB923C),
            icon: Icons.thermostat_rounded,
            gradient: const [Color(0xFFFFB900), Color(0xFFFF6900)],
            onChanged: (v) => store.update((s) => s.copyWith(tempThreshold: v)),
            minLabel: '0°C',
            maxLabel: '50°C',
          ),
          const SizedBox(height: 25),
          _ThresholdSlider(
            label: 'Humidity',
            value: settings.humidityThreshold,
            min: 0,
            max: 100,
            unit: '%',
            iconBg: const Color(0xFFEFF6FF),
            iconColor: const Color(0xFF2B7FFF),
            icon: Icons.water_drop_outlined,
            gradient: const [Color(0xFF00BCFF), Color(0xFF2B7FFF)],
            onChanged: (v) =>
                store.update((s) => s.copyWith(humidityThreshold: v)),
            minLabel: '0%',
            maxLabel: '100%',
          ),
          const SizedBox(height: 25),
          _ThresholdSlider(
            label: 'Wind',
            value: settings.windThreshold.clamp(0, 100),
            min: 0,
            max: 100,
            unit: 'km/h',
            iconBg: const Color(0xFFECFDF5),
            iconColor: const Color(0xFF00BC7D),
            icon: Icons.air_rounded,
            gradient: const [Color(0xFF00D5BE), Color(0xFF00BC7D)],
            onChanged: (v) => store.update((s) => s.copyWith(windThreshold: v)),
            minLabel: '0km/h',
            maxLabel: '100km/h',
          ),
          const SizedBox(height: 25),
          _ThresholdSlider(
            label: 'Risk Trigger',
            value: settings.riskThreshold.clamp(0, 100),
            min: 0,
            max: 100,
            unit: '%',
            iconBg: const Color(0xFFFFE4E6),
            iconColor: const Color(0xFFBA0C0C),
            icon: Icons.local_fire_department_rounded,
            gradient: const [Color(0xFFFFB900), Color(0xFFBA0C0C)],
            onChanged: (v) =>
                store.update((s) => s.copyWith(riskThreshold: v)),
            minLabel: '0%',
            maxLabel: '100%',
          ),
          const SizedBox(height: 25),
          _ThresholdSlider(
            label: 'Make it Rain Trigger',
            value: settings.makeItRainThreshold.clamp(0, 100),
            min: 0,
            max: 100,
            unit: '%',
            iconBg: const Color(0xFFE0F2FE),
            iconColor: const Color(0xFF0284C7),
            icon: Icons.water_drop_rounded,
            gradient: const [Color(0xFF38BDF8), Color(0xFF0284C7)],
            onChanged: (v) =>
                store.update((s) => s.copyWith(makeItRainThreshold: v)),
            minLabel: '0%',
            maxLabel: '100%',
          ),
          const SizedBox(height: 6),
          Text(
            'Risk above ${settings.makeItRainThreshold.toStringAsFixed(0)}% pops '
            'the "Make it Rain" prompt for manual activation.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF62748E)),
          ),
          const Divider(color: Color(0xFFF1F5F9), height: 40),
          const Text(
            'Activation Mode',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Color(0xFF272727),
              height: 19 / 18,
              letterSpacing: -0.315,
            ),
          ),
          const SizedBox(height: 14),
          _ToggleRow(
            icon: Icons.bolt_rounded,
            iconBg: const Color(0xFFF5F3FF),
            iconColor: const Color(0xFF7C3AED),
            title: 'Auto-Activation',
            subtitle: 'Choose activation trigger method',
            value: settings.autoActivation,
            onChanged: (v) =>
                store.update((s) => s.copyWith(autoActivation: v)),
          ),
          const SizedBox(height: 16),
          _RadioRow(
            label: 'AI-driven (model decides timing)',
            selected: settings.activationMode == ActivationMode.ai,
            onTap: () => store.update(
                (s) => s.copyWith(activationMode: ActivationMode.ai)),
          ),
          const SizedBox(height: 19),
          _RadioRow(
            label:
                'Risk threshold (>${settings.riskThreshold.toStringAsFixed(0)}% triggers)',
            selected: settings.activationMode == ActivationMode.threshold,
            onTap: () => store.update(
                (s) => s.copyWith(activationMode: ActivationMode.threshold)),
          ),
          const SizedBox(height: 19),
          _RadioRow(
            label: 'Off (manual only)',
            selected: settings.activationMode == ActivationMode.off,
            onTap: () => store.update(
                (s) => s.copyWith(activationMode: ActivationMode.off)),
          ),
          const Divider(color: Color(0xFFF1F5F9), height: 40),
          const Text(
            'Preferences',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Color(0xFF272727),
              height: 19 / 18,
              letterSpacing: -0.315,
            ),
          ),
          const SizedBox(height: 14),
          _ToggleRow(
            icon: Icons.notifications_active_outlined,
            iconBg: const Color(0xFFF5F3FF),
            iconColor: const Color(0xFF7C3AED),
            title: 'Enable Alerts',
            subtitle: 'On by default · Admin managed',
            value: settings.enableAlerts,
            onChanged: (v) =>
                store.update((s) => s.copyWith(enableAlerts: v)),
          ),
          const SizedBox(height: 16),
          const _ToggleRow(
            icon: Icons.person_outline_rounded,
            iconBg: Color(0xFFFFF1F2),
            iconColor: Color(0xFFE11D48),
            title: 'Admin Controls',
            subtitle: 'Manage at admin level',
            value: null,
            onChanged: null,
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => _confirmSignOut(context),
            child: const _ToggleRow(
              icon: Icons.logout_rounded,
              iconBg: Color(0xFFFEE2E2),
              iconColor: Color(0xFFBA0C0C),
              title: 'Sign Out',
              subtitle: 'Return to the login screen',
              value: null,
              onChanged: null,
            ),
          ),
          const SizedBox(height: 28),
          _SaveChangesPill(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings saved')),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

Future<void> _confirmSignOut(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text(
        'You will need to sign in again to access your zones and alerts.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFBA0C0C)),
          child: const Text('Sign out'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await AuthService.instance.signOut();
  ZoneStore.instance.deactivateAll();
  if (!context.mounted) return;
  // Go straight to the login screen and wipe the back stack. Explicit nav
  // (not just relying on the _AuthGate rebuild) so it works on every
  // platform and regardless of auth-stream timing.
  Navigator.of(context).pushNamedAndRemoveUntil(
    AppRoutes.login,
    (route) => false,
  );
}

class _SaveChangesPill extends StatelessWidget {
  const _SaveChangesPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(61),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF092C1B),
          borderRadius: BorderRadius.circular(61),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.local_fire_department_rounded,
                color: Colors.white, size: 24),
            SizedBox(width: 5),
            Text(
              'Save Changes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 19 / 16,
                letterSpacing: -0.315,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThresholdSlider extends StatelessWidget {
  const _ThresholdSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.iconBg,
    required this.iconColor,
    required this.icon,
    required this.gradient,
    required this.onChanged,
    required this.minLabel,
    required this.maxLabel,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final Color iconBg;
  final Color iconColor;
  final IconData icon;
  final List<Color> gradient;
  final ValueChanged<double> onChanged;
  final String minLabel;
  final String maxLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(5)),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF314158),
                      fontWeight: FontWeight.w500)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(4),
              ),
              child: RichText(
                text: TextSpan(
                  text: value.toStringAsFixed(0),
                  style: const TextStyle(
                    color: Color(0xFF0F172B),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(
                      text: ' $unit',
                      style: const TextStyle(
                        color: Color(0xFF62748E),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            activeTrackColor: gradient.last,
            inactiveTrackColor: const Color(0xFFF1F5F9),
            thumbColor: Colors.white,
            overlayColor: gradient.last.withValues(alpha: 0.1),
            thumbShape: _BorderedThumb(color: gradient.last),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(minLabel,
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF90A1B9))),
            Text(maxLabel,
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF90A1B9))),
          ],
        ),
      ],
    );
  }
}

class _BorderedThumb extends SliderComponentShape {
  _BorderedThumb({required this.color});
  final Color color;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(20, 20);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final fill = Paint()..color = Colors.white;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, 10, fill);
    canvas.drawCircle(center, 10, stroke);
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool? value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              color: iconBg, borderRadius: BorderRadius.circular(5)),
          alignment: Alignment.center,
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF314158))),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF62748E))),
            ],
          ),
        ),
        if (value != null && onChanged != null)
          Switch(
            value: value!,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF0F172B),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFE5E7EB),
          ),
      ],
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.primary : const Color(0xFFCBD5E1),
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF62748E))),
            ),
          ],
        ),
      ),
    );
  }
}
