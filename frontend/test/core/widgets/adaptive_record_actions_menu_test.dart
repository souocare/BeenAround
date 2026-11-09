import 'package:beenaround/core/widgets/adaptive_record_actions_menu.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('iOS opens Cupertino action sheet', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveRecordActionsMenu(onEdit: () {}, onDelete: () {}),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('recordActionsMenu')));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoActionSheet), findsOneWidget);

      expect(find.byKey(const Key('recordActionEdit')), findsOneWidget);

      expect(find.byKey(const Key('recordActionDelete')), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
