import 'package:beenaround/app/theme/app_theme.dart';
import 'package:beenaround/app/widgets/app_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    final theme = brightness == Brightness.dark
        ? AppTheme.dark
        : AppTheme.light;

    group('${brightness.name} theme', () {
      Future<void> pumpHeader(WidgetTester tester, Widget child) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Padding(padding: const EdgeInsets.all(24), child: child),
            ),
          ),
        );
      }

      testWidgets('displays title without optional content', (tester) async {
        await pumpHeader(
          tester,
          const AppSectionHeader(title: 'Visited Countries'),
        );

        expect(find.text('Visited Countries'), findsOneWidget);
        expect(find.byType(TextButton), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('displays optional subtitle', (tester) async {
        await pumpHeader(
          tester,
          const AppSectionHeader(
            title: 'Visited Countries',
            subtitle: 'Your travel history.',
          ),
        );

        expect(find.text('Visited Countries'), findsOneWidget);
        expect(find.text('Your travel history.'), findsOneWidget);
      });

      testWidgets('displays action and invokes callback', (tester) async {
        var calls = 0;

        await pumpHeader(
          tester,
          AppSectionHeader(
            title: 'Visited Countries',
            actionLabel: 'See All',
            onAction: () => calls++,
          ),
        );

        expect(find.text('See All'), findsOneWidget);

        await tester.tap(find.text('See All'));

        expect(calls, 1);
      });

      testWidgets('supports long titles without overflow', (tester) async {
        await pumpHeader(
          tester,
          AppSectionHeader(
            title: 'Countries and destinations visited throughout the years',
            subtitle: 'Your complete travel history.',
            actionLabel: 'See All',
            onAction: () {},
          ),
        );

        expect(tester.takeException(), isNull);
      });
    });
  }
}
