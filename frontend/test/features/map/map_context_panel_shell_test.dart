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
  });
}
