import 'package:flutter_test/flutter_test.dart';
import 'package:safeloop/main.dart';

void main() {
  testWidgets('SafeLoop smoke test - loads onboarding and app successfully',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SafeLoopApp());
    await tester.pump();

    // Verify SheMove brand title exists
    expect(find.text('SheMove'), findsOneWidget);
    expect(find.text('Protected Journeys'), findsOneWidget);
  });
}
