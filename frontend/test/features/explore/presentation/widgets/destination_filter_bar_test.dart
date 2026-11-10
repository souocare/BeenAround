import 'package:beenaround/features/explore/application/explore_destination_filter.dart';
import 'package:beenaround/features/explore/presentation/widgets/destination_filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpFilterBar(
    WidgetTester tester, {
    ExploreDestinationFilter selectedFilter = ExploreDestinationFilter.all,
    ValueChanged<ExploreDestinationFilter>? onSelected,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: DestinationFilterBar(
              keyPrefix: 'testFilter',
              selectedFilter: selectedFilter,
              onSelected: onSelected ?? (_) {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders all destination filters', (tester) async {
    await pumpFilterBar(tester);

    for (final filter in ExploreDestinationFilter.values) {
      expect(find.byKey(Key('testFilter-${filter.name}')), findsOneWidget);
    }
  });

  testWidgets('marks the selected filter', (tester) async {
    await pumpFilterBar(tester, selectedFilter: ExploreDestinationFilter.been);

    final chip = tester.widget<ChoiceChip>(
      find.byKey(const Key('testFilter-been')),
    );

    expect(chip.selected, isTrue);
  });

  testWidgets('notifies parent when filter changes', (tester) async {
    ExploreDestinationFilter? selected;

    await pumpFilterBar(tester, onSelected: (filter) => selected = filter);

    await tester.tap(find.byKey(const Key('testFilter-been')));

    expect(selected, ExploreDestinationFilter.been);
  });

  testWidgets('supports horizontal scrolling without overflow', (tester) async {
    await pumpFilterBar(tester);

    final scrollable = find.descendant(
      of: find.byType(DestinationFilterBar),
      matching: find.byType(SingleChildScrollView),
    );

    expect(scrollable, findsOneWidget);

    expect(
      tester.widget<SingleChildScrollView>(scrollable).scrollDirection,
      Axis.horizontal,
    );

    await tester.drag(scrollable, const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps selected filter visible after changing selection', (
    tester,
  ) async {
    var selected = ExploreDestinationFilter.all;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: StatefulBuilder(
              builder: (context, setState) {
                return DestinationFilterBar(
                  keyPrefix: 'testFilter',
                  selectedFilter: selected,
                  onSelected: (filter) {
                    setState(() => selected = filter);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );

    final scrollable = find.descendant(
      of: find.byType(DestinationFilterBar),
      matching: find.byType(SingleChildScrollView),
    );

    await tester.drag(scrollable, const Offset(-400, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('testFilter-multipleVisits')));

    await tester.pumpAndSettle();

    expect(selected, ExploreDestinationFilter.multipleVisits);
    expect(tester.takeException(), isNull);
  });
}
