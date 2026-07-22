// Smoke test for RainFire: verifies the app boots into the LOGIN screen
// with the expected welcome copy.

import 'package:flutter_test/flutter_test.dart';

import 'package:rainfire/main.dart';

void main() {
  testWidgets('Login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const RainFireApp());
    await tester.pump();

    expect(find.textContaining('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
