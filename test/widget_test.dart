// Basic smoke test for the Volunteer Connect app.

import 'package:flutter_test/flutter_test.dart';

import 'package:event_volunteer/main.dart';

void main() {
  testWidgets('App shows splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const VolunteerApp());

    expect(find.text('Volunteer Connect'), findsWidgets);

    // Let the splash timer fire and navigate to the Welcome screen.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('What is Volunteer Connect?'), findsOneWidget);
  });
}