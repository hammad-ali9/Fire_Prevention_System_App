// Smoke test for the Fire Prevention prototype: verifies the app boots into
// the LOGIN screen with the expected welcome copy.

import 'package:flutter_test/flutter_test.dart';

import 'package:fire_prevention/main.dart';

void main() {
  testWidgets('Login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const FirePreventionApp());
    await tester.pump();

    expect(find.textContaining('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
