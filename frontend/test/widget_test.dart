import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beenaround/app/app.dart';

void main() {
  testWidgets('BeenAround app starts successfully', (tester) async {
    await tester.pumpWidget(const BeenAroundApp());

    expect(find.text('BeenAround'), findsOneWidget);
    expect(find.text('Your world. Your journeys.'), findsOneWidget);
    expect(find.text('Authentication coming soon'), findsOneWidget);
  });

  testWidgets('BeenAround uses dark theme by default', (tester) async {
    await tester.pumpWidget(const BeenAroundApp());

    final context = tester.element(find.text('BeenAround'));
    final theme = Theme.of(context);

    expect(theme.brightness, Brightness.dark);
    expect(theme.useMaterial3, isTrue);
  });

  testWidgets('BeenAround does not show debug banner', (tester) async {
    await tester.pumpWidget(const BeenAroundApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(app.title, 'BeenAround');
  });
}
