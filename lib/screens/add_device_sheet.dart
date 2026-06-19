import 'package:flutter/material.dart';

import '../models/device.dart';
import '../models/zone.dart';
import '../services/device_store.dart';
import '../services/tg_service.dart';
import '../theme/app_colors.dart';

class AddDeviceSheet {
  static Future<void> show(BuildContext context, Zone zone) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _Sheet(zone: zone),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet shell
// ─────────────────────────────────────────────────────────────────────────────

class _Sheet extends StatefulWidget {
  const _Sheet({required this.zone});
  final Zone zone;

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  int _step = 0;

  // Step 1
  String? _type;
  final _serialCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();

  // Step 2
  final _orgCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _connector = 'TG';
  String _retrievalMode = 'query_tg';

  // Step 3 — data fields
  final Set<String> _dataFields = {'Locations', 'Trip Data'};

  // Pre-activation check results
  _CheckStatus _checkAsset = _CheckStatus.idle;
  _CheckStatus _checkConnector = _CheckStatus.idle;
  _CheckStatus _checkCredentials = _CheckStatus.idle;
  // IP allowlisting is always a manual step — never auto-resolved.
  final _CheckStatus _checkIp = _CheckStatus.manual;

  @override
  void dispose() {
    _serialCtrl.dispose();
    _regionCtrl.dispose();
    _orgCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _selectType(String type) {
    setState(() => _type = type);
    if (type == 'sprinkler') {
      // Auto-fill all known client credentials so the user doesn't have to
      // type them manually — they're pre-confirmed by the client brief.
      _serialCtrl.text = '1429272';
      _regionCtrl.text = 'EMEA03';
      _orgCtrl.text = 'Datanet IoT';
      _connector = 'TG';
      _retrievalMode = 'query_tg';
    } else {
      // Clear sprinkler-specific pre-fills when switching to another type.
      if (_serialCtrl.text == '1429272') _serialCtrl.clear();
      if (_regionCtrl.text == 'EMEA03') _regionCtrl.clear();
      if (_orgCtrl.text == 'Datanet IoT') _orgCtrl.clear();
    }
  }

  void _next() {
    setState(() => _step++);
    if (_step == 2) _runChecks();
  }

  Future<void> _runChecks() async {
    // Reset to loading
    setState(() {
      _checkAsset = _CheckStatus.loading;
      _checkConnector = _CheckStatus.loading;
      _checkCredentials = _CheckStatus.loading;
    });

    // Connector check is local — no network needed
    await Future.delayed(const Duration(milliseconds: 400));
    setState(() {
      _checkConnector = _connector == 'TG'
          ? _CheckStatus.passed
          : _CheckStatus.failed;
    });

    // Step 1: Check API credentials — GET /v2/user/organisations
    try {
      await TGService.instance.fetchOrganisations();
      setState(() => _checkCredentials = _CheckStatus.passed);
    } on TGAuthException {
      setState(() {
        _checkCredentials = _CheckStatus.failed;
        // If auth fails, skip asset check — no point calling with bad creds
        _checkAsset = _CheckStatus.failed;
      });
      return;
    } catch (_) {
      setState(() {
        _checkCredentials = _CheckStatus.failed;
        _checkAsset = _CheckStatus.failed;
      });
      return;
    }

    // Step 2: Check asset exists — GET /v3/assets/{orgId}, find serial
    try {
      final serial = _serialCtrl.text.trim();
      await TGService.instance.fetchTelemetry(serial);
      setState(() => _checkAsset = _CheckStatus.passed);
    } on TGNotFoundException {
      setState(() => _checkAsset = _CheckStatus.failed);
    } catch (_) {
      setState(() => _checkAsset = _CheckStatus.failed);
    }
  }

  bool get _checksAllowActivation =>
      _checkCredentials != _CheckStatus.failed &&
      _checkAsset != _CheckStatus.failed;

  void _showIpAllowlistingGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4EC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.shield_outlined,
                          size: 20, color: Color(0xFFF97316)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'IP Allowlisting Guide',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _GuideStep(
                  number: '1',
                  title: 'Find your current IP',
                  body: 'Visit whatismyip.com on the device or network that will run this app. Copy the IPv4 address shown.',
                ),
                const SizedBox(height: 14),
                const _GuideStep(
                  number: '2',
                  title: 'For testing — disable allowlisting',
                  body: 'Log in to TG EMEA03 → Organisation Settings → API Access → temporarily disable IP restriction. Re-enable after confirming the connection works.',
                ),
                const SizedBox(height: 14),
                const _GuideStep(
                  number: '3',
                  title: 'For production — use a fixed IP proxy',
                  body: 'Deploy a Firebase Cloud Function as a proxy between this app and TG. The Function\'s static outbound IP is what gets allowlisted — not the phone\'s dynamic IP.',
                ),
                const SizedBox(height: 14),
                const _GuideStep(
                  number: '4',
                  title: 'Add the IP in TG',
                  body: 'TG EMEA03 → Organisation Settings → IP Allowlist → Add IP → paste your IP or proxy IP → Save.',
                ),
                const SizedBox(height: 14),
                const _GuideStep(
                  number: '5',
                  title: 'Need help?',
                  body: 'Contact Digital Matter support at support.digitalmatter.com/contact-support — ask them to whitelist your IP for org "Datanet IoT" on EMEA03.',
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Got it',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
  }

  void _activate() {
    DeviceStore.instance.add(Device(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      zoneId: widget.zone.id,
      type: _type ?? 'gps_tracker',
      serialNumber: _serialCtrl.text.trim(),
      serverRegion: _regionCtrl.text.trim(),
      organization: _orgCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      connector: _connector,
      retrievalMode: _retrievalMode,
      dataFields: _dataFields.toList(),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return Container(
      height: h * 0.93,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          // header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _back,
                  child: Container(
                    width: 55,
                    height: 55,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE9E9E9)),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        size: 22, color: Color(0xFF272727)),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _stepTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF272727),
                        letterSpacing: -0.315,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 55),
              ],
            ),
          ),
          // step indicator
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
            child: _Stepper(current: _step),
          ),
          const SizedBox(height: 20),
          // scrollable content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: SingleChildScrollView(
                key: ValueKey(_step),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                child: _buildStepContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _stepTitle {
    switch (_step) {
      case 0:
        return 'Add New Device';
      case 1:
        return 'Device Details';
      default:
        return 'Confirm Device';
    }
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      default:
        return _buildStep3();
    }
  }

  // ── Step 1: type + serial ─────────────────────────────────────────────────

  Widget _buildStep1() {
    const types = [
      ('gps_tracker', 'GPS Tracker', 'Location & Motion',
          Icons.gps_fixed_rounded),
      ('zone_sensor', 'Zone Sensor', 'Area monitoring', Icons.sensors_rounded),
      ('env_monitor', 'Env. Monitor', 'Temp, humidity',
          Icons.thermostat_rounded),
      ('sprinkler', 'Water Sprinkler', 'TG EMEA03 · IoT',
          Icons.water_rounded),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Select Device Type'),
        const SizedBox(height: 11),
        // 2-column grid
        for (int row = 0; row < 2; row++) ...[
          Row(
            children: [
              for (int col = 0; col < 2; col++) ...[
                Expanded(
                  child: _DeviceTypeCard(
                    id: types[row * 2 + col].$1,
                    label: types[row * 2 + col].$2,
                    subtitle: types[row * 2 + col].$3,
                    icon: types[row * 2 + col].$4,
                    selected: _type == types[row * 2 + col].$1,
                    onTap: () => _selectType(types[row * 2 + col].$1),
                  ),
                ),
                if (col == 0) const SizedBox(width: 13),
              ],
            ],
          ),
          if (row == 0) const SizedBox(height: 13),
        ],
        const SizedBox(height: 24),
        if (_type == 'sprinkler') ...[
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4FD),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline_rounded,
                    size: 18, color: Color(0xFF0284C7)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'User credentials auto-filled — Serial 1429272 · TG EMEA03 · Datanet IoT',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF0284C7),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        const _SectionLabel('Device Serial Number'),
        const SizedBox(height: 13),
        _PillField(
          label: 'Serial Number',
          controller: _serialCtrl,
          icon: Icons.tag_rounded,
          readOnly: _type == 'sprinkler',
        ),
        const SizedBox(height: 13),
        _PillField(
          label: 'Server Region',
          controller: _regionCtrl,
          icon: Icons.public_rounded,
          readOnly: _type == 'sprinkler',
        ),
        const SizedBox(height: 28),
        _ActionButton(
          label: 'Continue',
          onTap: (_type != null && _serialCtrl.text.isNotEmpty) ? _next : null,
        ),
      ],
    );
  }

  // ── Step 2: asset identity + connector ───────────────────────────────────

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Asset Identity'),
        const SizedBox(height: 21),
        // serial from step 1 (pre-filled, read-only)
        _PillField(
          label: 'Serial Number',
          controller: TextEditingController(text: _serialCtrl.text),
          icon: Icons.tag_rounded,
          readOnly: true,
        ),
        const SizedBox(height: 13),
        _PillField(
          label: 'Organization',
          controller: _orgCtrl,
          icon: Icons.business_outlined,
        ),
        const SizedBox(height: 13),
        _PillField(
          label: 'Zone Assignment',
          controller:
              TextEditingController(text: widget.zone.name),
          icon: Icons.layers_outlined,
          readOnly: true,
        ),
        const SizedBox(height: 13),
        _PillField(
          label: 'Description (Optional)',
          controller: _descCtrl,
          icon: Icons.notes_rounded,
        ),
        const SizedBox(height: 24),
        const _SectionLabel('Connector & Data Method'),
        const SizedBox(height: 15),
        _RadioOption(
          label: 'TG (EME0A3)',
          value: 'TG',
          groupValue: _connector,
          onChanged: (v) => setState(() => _connector = v),
        ),
        const SizedBox(height: 19),
        _RadioOption(
          label: 'Direct MQTT',
          value: 'Direct MQTT',
          groupValue: _connector,
          onChanged: (v) => setState(() => _connector = v),
        ),
        const SizedBox(height: 19),
        _RadioOption(
          label: 'Web hook Push',
          value: 'Webhook Push',
          groupValue: _connector,
          onChanged: (v) => setState(() => _connector = v),
        ),
        const SizedBox(height: 24),
        const _SectionLabel('Data Retrieval Mode'),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFEAEAEA)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ToggleChip(
                    label: 'Query From TG',
                    selected: _retrievalMode == 'query_tg',
                    onTap: () => setState(() => _retrievalMode = 'query_tg'),
                  ),
                  const SizedBox(width: 18),
                  _ToggleChip(
                    label: 'Webhook ( Push )',
                    selected: _retrievalMode == 'webhook',
                    onTap: () => setState(() => _retrievalMode = 'webhook'),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              const Text(
                'Device data is pulled on demand via the TG connector '
                'and synced to the zone monitoring system.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0x9962748E),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _ActionButton(label: 'Continue', onTap: _next),
      ],
    );
  }

  // ── Step 3: confirm + activate ────────────────────────────────────────────

  Widget _buildStep3() {
    final tempDevice = Device(
      id: '',
      zoneId: widget.zone.id,
      type: _type ?? 'gps_tracker',
      serialNumber: _serialCtrl.text.trim(),
      serverRegion: _regionCtrl.text.trim(),
      organization: _orgCtrl.text.trim(),
      connector: _connector,
      retrievalMode: _retrievalMode,
      dataFields: _dataFields.toList(),
    );

    const allFields = [
      'Locations',
      'Trip Data',
      'Temperature',
      'Humidity',
      'Motion',
      'Battery',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Device Summary'),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(9, 24, 9, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFEAEAEA)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              _SummaryRow('Type', tempDevice.typeLabel),
              const SizedBox(height: 17),
              _SummaryRow('Serial', tempDevice.serialNumber.isEmpty ? '—' : tempDevice.serialNumber),
              const SizedBox(height: 17),
              _SummaryRow('Region', tempDevice.serverRegion.isEmpty ? '—' : tempDevice.serverRegion),
              const SizedBox(height: 17),
              _SummaryRow('Organization', tempDevice.organization.isEmpty ? '—' : tempDevice.organization),
              const SizedBox(height: 17),
              _SummaryRow('Connector', tempDevice.connectorLabel),
              const SizedBox(height: 17),
              _SummaryRow('Access Method', tempDevice.retrievalLabel),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _SectionLabel('Data Fields Requested'),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFEAEAEA)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Wrap(
            spacing: 18,
            runSpacing: 10,
            children: allFields.map((f) {
              final selected = _dataFields.contains(f);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _dataFields.remove(f);
                  } else {
                    _dataFields.add(f);
                  }
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.transparent,
                    border: selected
                        ? null
                        : Border.all(color: const Color(0xFFD7D7D7)),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Text(
                    f,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? Colors.white
                          : const Color(0xFF62748E),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        const _SectionLabel('Pre-Activation Checks'),
        const SizedBox(height: 15),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFEAEAEA)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              _CheckRow('Assets exists in TG', _checkAsset),
              _CheckRow('Connector Set', _checkConnector),
              _CheckRow('API Credentials', _checkCredentials),
              _CheckRow(
                'IP Allowlisting',
                _checkIp,
                last: true,
                onManualTap: () => _showIpAllowlistingGuide(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _ActionButton(
          label: 'Activate Device',
          onTap: _checksAllowActivation ? _activate : null,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step Indicator
// ─────────────────────────────────────────────────────────────────────────────

class _Stepper extends StatelessWidget {
  const _Stepper({required this.current});
  final int current; // 0-indexed current step

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepDot(number: 1, current: current, index: 0),
        Expanded(child: _DashLine(filled: current >= 1)),
        _StepDot(number: 2, current: current, index: 1),
        Expanded(child: _DashLine(filled: current >= 2)),
        _StepDot(number: 3, current: current, index: 2),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot(
      {required this.number, required this.current, required this.index});
  final int number;
  final int current;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (index == current) {
      // active
      return Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.15),
              border:
                  Border.all(color: AppColors.primary, width: 2),
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
          ),
        ],
      );
    } else if (index < current) {
      // completed
      return Container(
        width: 26,
        height: 26,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary,
        ),
        alignment: Alignment.center,
        child: Text(
          '$number',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else {
      // idle
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD0D0D0), width: 1.5),
        ),
      );
    }
  }
}

class _DashLine extends StatelessWidget {
  const _DashLine({this.filled = false});
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: LayoutBuilder(
        builder: (context, c) {
          const dw = 5.0, gap = 4.0;
          final count = (c.maxWidth / (dw + gap)).floor();
          final color =
              filled ? AppColors.primary : const Color(0xFFD0D0D0);
          return Row(
            children: List.generate(
              count,
              (_) => Padding(
                padding: const EdgeInsets.only(right: gap),
                child: Container(width: dw, height: 1, color: color),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: Color(0xFF272727),
        letterSpacing: -0.315,
      ),
    );
  }
}

class _DeviceTypeCard extends StatelessWidget {
  const _DeviceTypeCard({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.white,
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFEAEAEA),
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 31,
              height: 31,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(15.5),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 17, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF272727),
                letterSpacing: -0.62,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF272727),
                letterSpacing: -0.315,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillField extends StatelessWidget {
  const _PillField({
    required this.label,
    required this.controller,
    this.icon,
    this.readOnly = false,
  });

  final String label;
  final TextEditingController controller;
  final IconData? icon;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111214),
            letterSpacing: -0.028,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F3F4),
            borderRadius: BorderRadius.circular(43),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: const Color(0xFF393C43)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  readOnly: readOnly,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF393C43),
                    letterSpacing: -0.048,
                  ),
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RadioOption extends StatelessWidget {
  const _RadioOption({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : const Color(0xFFD0D0D0),
                    width: 1.5,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 11),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              color: const Color(0xFF62748E),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          border:
              selected ? null : Border.all(color: const Color(0xFFD7D7D7)),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF62748E),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0x991D1B1B),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xCC1D1B1B),
          ),
        ),
      ],
    );
  }
}

enum _CheckStatus { idle, loading, passed, failed, manual }

class _CheckRow extends StatelessWidget {
  const _CheckRow(this.check, this.status, {this.last = false, this.onManualTap});
  final String check;
  final _CheckStatus status;
  final bool last;
  final VoidCallback? onManualTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 0, 9, 0),
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFEAEAEA), width: 0.5),
              ),
            ),
      height: 43,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            check,
            style: const TextStyle(fontSize: 16, color: Color(0x991D1B1B)),
          ),
          _badge(status),
        ],
      ),
    );
  }

  Widget _badge(_CheckStatus s) {
    switch (s) {
      case _CheckStatus.loading:
        return const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF90A1B9)),
        );
      case _CheckStatus.passed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
            SizedBox(width: 5),
            Text('Verified',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF16A34A))),
          ],
        );
      case _CheckStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.cancel_rounded, size: 16, color: Color(0xFFBA0C0C)),
            SizedBox(width: 5),
            Text('Failed',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFBA0C0C))),
          ],
        );
      case _CheckStatus.manual:
        return GestureDetector(
          onTap: onManualTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4EC),
              border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('Check IT',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF97316))),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 11, color: Color(0xFFF97316)),
              ],
            ),
          ),
        );
      case _CheckStatus.idle:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD7D7D7)),
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Text('Pending',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF62748E))),
        );
    }
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: onTap != null
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(61),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.315,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.number,
    required this.title,
    required this.body,
  });
  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172B),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF62748E),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
