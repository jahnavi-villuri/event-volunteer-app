import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:event_volunteer/main.dart';
import 'package:event_volunteer/services/session.dart';
import 'package:event_volunteer/theme/app_theme.dart';

void main() {
  testWidgets('Home quick actions navigate through the persistent tabs', (
    tester,
  ) async {
    Session.clear();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const VolunteerHomeScreen(user: {'name': 'Test Volunteer'}),
      ),
    );

    expect(find.text('Hello, Test Volunteer 👋'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );

    await tester.tap(find.text('View Events').first);
    await tester.pump();

    expect(find.text('Find events and choose volunteer work.'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );

    await tester.tap(find.text('Home'));
    await tester.pump();

    await tester.tap(find.text('My Tasks').first);
    await tester.pump();

    expect(
      find.text('Your shifts, status and event details in one place.'),
      findsOneWidget,
    );
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );

    await tester.tap(find.text('Home'));
    await tester.pump();

    expect(find.text('Hello, Test Volunteer 👋'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });
}
