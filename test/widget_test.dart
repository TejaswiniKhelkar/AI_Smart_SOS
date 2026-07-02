// Basic smoke test for AI Smart SOS app.

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_smart_sos/main.dart';

void main() {
  testWidgets('App renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartSOSApp());
    expect(find.text('AI SMART SOS'), findsOneWidget);
  });
}
