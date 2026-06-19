import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Labelled pill input used on login + form screens. Matches Figma 1:312
/// (Email Address, Password) with a leading icon and optional trailing widget.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.icon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final IconData? icon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            letterSpacing: -0.028,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 50,
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: const TextStyle(
              color: AppColors.textBody,
              fontSize: 16,
              letterSpacing: -0.3,
            ),
            decoration: InputDecoration(
              hintText: hint,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 0),
              prefixIcon: icon == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(left: 16, right: 8),
                      child: Icon(icon, color: AppColors.textBody, size: 20),
                    ),
              prefixIconConstraints: const BoxConstraints(minWidth: 46),
              suffixIcon: suffix,
            ),
          ),
        ),
      ],
    );
  }
}
