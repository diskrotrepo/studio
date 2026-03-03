import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_ui/theme/app_theme.dart';

void main() {
  testWidgets('Material app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: const Scaffold(
          body: Center(child: Text('Studio')),
        ),
      ),
    );

    expect(find.text('Studio'), findsOneWidget);
  });
}
