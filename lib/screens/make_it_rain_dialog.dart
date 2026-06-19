import 'package:flutter/material.dart';

import '../models/activation_entry.dart';
import '../models/zone.dart';
import '../routes/app_routes.dart';
import '../services/zone_store.dart';
import '../theme/app_colors.dart';

/// HIGH-RISK PROMPT — shown when a zone's risk crosses the critical threshold
/// (> 80%). Asks the operator to manually trigger "Make it Rain", which fires
/// the sensor immobilisation function (sprinkler activation) for the zone.
///
/// Manual activation only — the system surfaces the decision, the human takes
/// it. (Automatic activation is a later, opt-in feature.)
class MakeItRainDialog extends StatelessWidget {
  const MakeItRainDialog({super.key, required this.zone});

  final Zone zone;

  /// Shows the prompt. Returns `true` if the operator chose "Make it Rain".
  /// On Cancel it routes to the zone's Environmental Scan ("zone data").
  static Future<bool> show(BuildContext context, Zone zone) async {
    final fired = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x66000000),
      builder: (_) => MakeItRainDialog(zone: zone),
    );
    if (fired == true) {
      // Manual activation = sensor immobilisation / sprinklers ON.
      ZoneStore.instance.activate(zone.id, source: ActivationSource.manual);
    } else if (context.mounted) {
      // Cancel → back to the zone data.
      Navigator.pushNamed(context, AppRoutes.envScan);
    }
    return fired == true;
  }

  @override
  Widget build(BuildContext context) {
    final risk = zone.riskPercent.toStringAsFixed(0);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 66,
                height: 66,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFFE5E5),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: Color(0xFFBA0C0C),
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                'High Risk — $risk%',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF272727),
                  letterSpacing: -0.315,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fire risk in ${zone.fullLabel} crossed the critical threshold. '
              'Do you want to activate "Make it Rain"? This triggers the '
              'sensor immobilisation function for this zone.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF565656),
                height: 19 / 14,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 26),
            _button(
              label: 'Make it Rain',
              icon: Icons.water_drop_rounded,
              background: const Color(0xFFBA0C0C),
              foreground: Colors.white,
              onTap: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 12),
            _button(
              label: 'Cancel',
              icon: Icons.close_rounded,
              background: AppColors.inputFill,
              foreground: const Color(0xFF393C43),
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _button({
    required String label,
    required IconData icon,
    required Color background,
    required Color foreground,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 51,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(61),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.315,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
