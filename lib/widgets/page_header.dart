import 'package:flutter/material.dart';

/// Header used inside screens that aren't part of the bottom-nav root:
/// circular back button + centered title. Matches Figma 1:989, 1:1064, etc.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 55,
      child: Row(
        children: [
          InkWell(
            onTap: onBack ?? () => Navigator.maybePop(context),
            borderRadius: BorderRadius.circular(28),
            child: Container(
              width: 55,
              height: 55,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE9E9E9)),
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 22),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF272727),
                ),
              ),
            ),
          ),
          if (trailing != null) trailing! else const SizedBox(width: 55),
        ],
      ),
    );
  }
}
