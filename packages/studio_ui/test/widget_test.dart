import 'package:flutter_test/flutter_test.dart';
import 'package:studio_ui/main.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const StudioApp());
    expect(find.text('Studio'), findsOneWidget);
  });
}
