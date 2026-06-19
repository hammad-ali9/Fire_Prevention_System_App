import 'package:flutter/material.dart';

/// Top spacer that yields to the phone's real OS status bar (time, signal,
/// wifi, battery come from the device). Kept as a widget so existing screens
/// don't have to change their layout structure.
class FakeStatusBar extends StatelessWidget {
  const FakeStatusBar({super.key, this.dark = false});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: MediaQuery.of(context).padding.top);
  }
}

/// Bottom home-indicator spacer — yields to the system gesture inset.
class NotchArea extends StatelessWidget {
  const NotchArea({super.key, this.dark = false});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return SizedBox(height: bottom > 0 ? bottom : 8);
  }
}
