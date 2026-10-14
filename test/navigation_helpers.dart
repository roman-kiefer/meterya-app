import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> selectSection(
  WidgetTester tester,
  double width,
  String label,
) async {
  if (width < 900) {
    await tester.tap(find.byTooltip('Menü öffnen'));
    await tester.pumpAndSettle();
  }
  final navigation = find.byType(
    width < 900 ? NavigationDrawer : NavigationRail,
  );
  await tester.tap(find.descendant(of: navigation, matching: find.text(label)));
  await tester.pumpAndSettle();
}
