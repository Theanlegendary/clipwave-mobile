import 'package:flutter_test/flutter_test.dart';
import 'package:clipwave_app/main.dart';

void main() {
  testWidgets('ClipwaveApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ClipwaveApp());
    expect(find.text('Clipwave'), findsOneWidget);
  });
}
