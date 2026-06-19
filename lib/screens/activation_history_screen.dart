import 'package:flutter/material.dart';

import '../models/activation_entry.dart';
import '../routes/app_routes.dart';
import '../services/history_store.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/page_header.dart';
import '../widgets/status_bar.dart';

/// ACTIVATION HISTORY — Figma node 1:1640. Driven by [HistoryStore].
class ActivationHistoryScreen extends StatelessWidget {
  const ActivationHistoryScreen({super.key});

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
                title: 'Activation History',
                onBack: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacementNamed(context, AppRoutes.home);
                  }
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ValueListenableBuilder<List<ActivationEntry>>(
                valueListenable: HistoryStore.instance.entries,
                builder: (context, items, _) {
                  if (items.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No activations yet. Activate a zone manually or wait for an automatic trigger.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF565656)),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _HistoryRow(item: items[i]),
                  );
                },
              ),
            ),
            const AppBottomNav(active: NavTab.history),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});
  final ActivationEntry item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFF1F5F9)),
          bottom: BorderSide(color: Color(0xFFF1F5F9)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE5E5),
              borderRadius: BorderRadius.circular(27),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.brightness_high,
              color: Color(0xFFFF1919),
              size: 23,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.zoneName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF272727),
                    height: 19 / 14,
                    letterSpacing: -0.315,
                  ),
                ),
                Text(
                  '${_relativeDay(item.startedAt)} · ${_hm(item.startedAt)} · ${item.sourceLabel}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0x80565656),
                    height: 19 / 12,
                    letterSpacing: -0.315,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _fmtDuration(item.duration),
            style: const TextStyle(
              color: Color(0xFF092C1B),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 24 / 14,
              letterSpacing: -0.3125,
            ),
          ),
        ],
      ),
    );
  }

  static String _hm(DateTime t) {
    final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  static String _relativeDay(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(t.year, t.month, t.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${t.month}/${t.day}';
  }

  static String _fmtDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
