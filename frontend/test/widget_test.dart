import 'package:beenaround/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('BeenAround app starts successfully', (tester) async {
    await tester.pumpWidget(const BeenAroundApp());

    // The application initializes asynchronously.
    await tester.pumpAndSettle();

    expect(find.text('BeenAround'), findsOneWidget);
    expect(find.text('Connect to your server'), findsOneWidget);
    expect(find.text('Connect to Server'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('BeenAround uses dark theme by default', (tester) async {
    await tester.pumpWidget(const BeenAroundApp());

    // Theme configuration is available immediately from MaterialApp.
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.themeMode, ThemeMode.dark);
    expect(app.darkTheme, isNotNull);
    expect(app.darkTheme!.brightness, Brightness.dark);
    expect(app.darkTheme!.useMaterial3, isTrue);
  });

  testWidgets('BeenAround does not show debug banner', (tester) async {
    await tester.pumpWidget(const BeenAroundApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(app.title, 'BeenAround');
  });
}
