import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/presentation/widgets/map_context_panel_shell.dart';

Widget buildTestPanel({
  required VoidCallback onClose,
  int compactRequestId = 0,
}) {
  return MaterialApp(
    home: Scaffold(
      body: MapContextPanelShell(
        onClose: onClose,
        compactRequestId: compactRequestId,
        contentBuilder: (context, scrollController, showDragHandle) {
          return CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    Text(
                      showDragHandle
                          ? 'Bottom panel content'
                          : 'Side panel content',
                    ),
                    const SizedBox(height: 800),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

void main() {
  group('MapContextPanelShell', () {
    testWidgets('renders a draggable panel in portrait', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestPanel(onClose: () {}));

      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      expect(find.text('Bottom panel content'), findsOneWidget);
      expect(find.text('Side panel content'), findsNothing);
    });

    testWidgets('renders a side panel in wide landscape', (tester) async {
      tester.view.physicalSize = const Size(1000, 600);
      tester.view.devicePixelRatio = 1;

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestPanel(onClose: () {}));

      expect(find.text('Side panel content'), findsOneWidget);
      expect(find.byType(DraggableScrollableSheet), findsNothing);
    });

    testWidgets('preserves scrollable content', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestPanel(onClose: () {}));

      expect(find.byType(CustomScrollView), findsOneWidget);
    });
    testWidgets('preserves shell state when geographic selection changes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Widget buildSelectedPanel(String selectionKey) {
        return MaterialApp(
          home: Scaffold(
            body: MapContextPanelShell(
              key: const ValueKey('persistentMapPanel'),
              selectionKey: selectionKey,
              onClose: () {},
              contentBuilder: (context, scrollController, showDragHandle) {
                return CustomScrollView(
                  controller: scrollController,
                  slivers: [SliverToBoxAdapter(child: Text(selectionKey))],
                );
              },
            ),
          ),
        );
      }

      await tester.pumpWidget(buildSelectedPanel('country:PT'));

      final initialState = tester.state(find.byType(MapContextPanelShell));

      expect(find.text('country:PT'), findsOneWidget);

      await tester.pumpWidget(buildSelectedPanel('city:10'));

      final updatedState = tester.state(find.byType(MapContextPanelShell));

      expect(identical(initialState, updatedState), isTrue);

      expect(find.text('city:10'), findsOneWidget);
      expect(find.text('country:PT'), findsNothing);
    });
  });
}
