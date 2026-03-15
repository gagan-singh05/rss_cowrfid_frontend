import 'package:flutter_test/flutter_test.dart';

import 'package:rss_frontend/main.dart';

void main() {
  testWidgets('App renders block selection grid', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // App bar title should be present
    expect(find.text('Cow RFID Controller'), findsOneWidget);

    // All four block buttons should be visible
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);

    // Status prompt should be visible when no session is active
    expect(find.text('Select a Block to Start Scanning'), findsOneWidget);
  });
}
