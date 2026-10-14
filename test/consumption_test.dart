import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meterya_app/consumption_view.dart';
import 'package:meterya_app/l10n/app_localizations.dart';
import 'package:meterya_app/models.dart';

void main() {
  test('quantity formatting preserves exact fractions and integer zeros', () {
    expect(displayQuantity('100.000000'), '100');
    expect(displayQuantity('100'), '100');
    expect(displayQuantity('0.000001'), '0,000001');
    expect(displayQuantity('99999999999999.999999'), '99999999999999,999999');
    expect(displayQuantity('12.500000'), '12,5');
    expect(displayQuantity('0.000000'), '0');
  });

  testWidgets(
    'shows separate import/export periods and a missing-reading hint',
    (tester) async {
      final point = Point.fromJson({
        'id': 'p',
        'name': 'Haus',
        'version': 3,
        'meter': {
          'serial': '123',
          'registers': [
            {'id': 'import', 'direction': 'IMPORT', 'unit': 'kWh'},
            {'id': 'export', 'direction': 'EXPORT', 'unit': 'kWh'},
          ],
        },
        'readings': [],
        'consumption': [
          {
            'register_id': 'import',
            'start_date': '2026-10-04',
            'end_date': '2026-10-05',
            'quantity': '0.000001',
            'unit': 'kWh',
          },
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ConsumptionView(point: point)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verbrauch zwischen Ablesungen'));
      await tester.pumpAndSettle();
      expect(find.text('Bezug'), findsOneWidget);
      expect(find.text('Einspeisung'), findsOneWidget);
      expect(find.text('0,000001 kWh'), findsOneWidget);
      expect(find.text('4.10.2026 bis 5.10.2026'), findsOneWidget);
      expect(
        find.text(
          'Für dieses Register werden mindestens zwei Ablesungen benötigt.',
        ),
        findsOneWidget,
      );
    },
  );
}
