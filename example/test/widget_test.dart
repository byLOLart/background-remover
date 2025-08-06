// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:background_remover/background_remover.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('Background Remover app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the title is displayed
    expect(find.text('Background Remover'), findsOneWidget);

    // Verify that the select image button is present
    expect(find.text('Seleccionar Imagen'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.photo), findsOneWidget);

    // Verify initial state - no image displayed
    expect(find.byType(ImageEditorWidget), findsNothing);
  });
}
