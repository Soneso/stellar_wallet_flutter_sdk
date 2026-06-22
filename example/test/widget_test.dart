// Smoke test for the Flutter Wallet SDK demo app.

import 'package:flutter_test/flutter_test.dart';

import 'package:example/activity_log.dart';
import 'package:example/main.dart';

void main() {
  testWidgets('renders example buttons and empty activity log',
      (WidgetTester tester) async {
    ActivityLog.instance.clear();
    await tester.pumpWidget(const MyApp());

    expect(find.text('Examples'), findsOneWidget);
    expect(find.text('SEP-001'), findsOneWidget);
    expect(find.text('SEP-010'), findsOneWidget);
    expect(find.text('SEP-024'), findsOneWidget);
    expect(find.text('SEP-030'), findsOneWidget);

    expect(find.text('Activity Log'), findsOneWidget);
    expect(
      find.text('No activity yet. Tap an example above to run it.'),
      findsOneWidget,
    );
  });

  testWidgets('shows entries after the activity log receives a message',
      (WidgetTester tester) async {
    ActivityLog.instance.clear();
    await tester.pumpWidget(const MyApp());

    logLine('hello from a test');
    await tester.pump();

    expect(find.textContaining('hello from a test'), findsOneWidget);
    expect(
      find.text('No activity yet. Tap an example above to run it.'),
      findsNothing,
    );
  });
}
