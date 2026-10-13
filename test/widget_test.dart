import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duo_ludo/main.dart';

void main() {
  testWidgets('DuoLudoApp smoke test - verifies home screen and game modes', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DuoLudoApp());
    await tester.pumpAndSettle();

    // Verify Title and Game Mode options exist
    expect(find.text('DUO LUDO'), findsOneWidget);
    expect(find.text('Pass & Play'), findsOneWidget);
    expect(find.text('Create Private Room'), findsOneWidget);
    expect(find.text('Join Room'), findsOneWidget);

    // Verify settings button
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });
}
