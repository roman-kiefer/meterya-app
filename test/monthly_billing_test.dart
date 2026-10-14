import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meterya_app/l10n/app_localizations.dart';
import 'package:meterya_app/models.dart';
import 'package:meterya_app/monthly_billing_view.dart';

void main() {
  for (final balance in ['6077', '-2002']) {
    testWidgets(
      'export statement labels received payments and balance $balance',
      (tester) async {
        final bill = MonthlyBill.fromJson({
          'year': 2026,
          'direction': 'EXPORT',
          'register_id': 'export',
          'complete': false,
          'opening_value': '8934.000000',
          'quantity': '3046.000000',
          'energy_cents': '24977',
          'base_cents': '0',
          'payment_cents': '18900',
          'total_cents': '24977',
          'balance_cents': balance,
          'rows': [
            {
              'date': '2026-01-31',
              'value': '8946.000000',
              'quantity': '12.000000',
              'unit_cents_per_1000': 8200,
              'base_cents': 0,
              'payment_cents': 2100,
              'energy_euros_exact': '0.984000000',
            },
          ],
        });
        final point = Point(
          'p',
          'Hauptzähler',
          'serial',
          1,
          const [
            Register('import', 'IMPORT', 'kWh'),
            Register('export', 'EXPORT', 'kWh'),
          ],
          const [],
          monthlyBilling: [bill],
        );
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: MonthlyBillingView(point: point),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Abrechnung nach Monatsständen'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('2026 · Einspeisung (2.8.0)'));
        await tester.pumpAndSettle();
        expect(find.text('8,2 ct/kWh'), findsOneWidget);
        expect(find.text('Erhaltene Auszahlungen'), findsWidgets);
        expect(
          find.text(
            balance == '6077'
                ? 'Ausstehende Vergütung'
                : 'Überzahlte Vergütung',
          ),
          findsOneWidget,
        );
        expect(
          find.text(balance == '6077' ? '60,77 €' : '20,02 €'),
          findsOneWidget,
        );
        expect(find.text('Nachzahlung'), findsNothing);
        expect(find.text('Oktober'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'monthly statement keeps exact costs and displays credit without future months',
    (tester) async {
      final bill = MonthlyBill.fromJson({
        'year': 2026,
        'complete': false,
        'opening_value': '4115.000000',
        'quantity': '1084.000000',
        'energy_cents': '35664',
        'base_cents': '12510',
        'payment_cents': '50400',
        'total_cents': '48174',
        'balance_cents': '-2226',
        'rows': [
          {
            'date': '2026-01-31',
            'value': '4267.000000',
            'quantity': '152.000000',
            'unit_cents_per_1000': 32900,
            'base_cents': 1390,
            'payment_cents': 5600,
            'energy_euros_exact': '50.008000000',
          },
        ],
      });
      final point = Point(
        'p',
        'OG Zähler',
        'OG-1',
        1,
        const [Register('r', 'IMPORT', 'kWh')],
        const [],
        monthlyBilling: [bill],
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyBillingView(point: point),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrechnung nach Monatsständen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026'));
      await tester.pumpAndSettle();
      expect(find.text('50,008 €'), findsOneWidget);
      expect(find.text('32,9 ct/kWh'), findsOneWidget);
      expect(find.text('Oktober'), findsNothing);
      expect(find.text('481,74 €'), findsOneWidget);
      expect(find.text('504,00 €'), findsOneWidget);
      expect(find.text('22,26 €'), findsOneWidget);
      expect(find.text('Guthaben'), findsOneWidget);
      expect(
        find.text('Unvollständiges Jahr · nur vorhandene Zeiträume'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
