import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meterya_app/calculated_monthly_view.dart';
import 'package:meterya_app/l10n/app_localizations.dart';
import 'package:meterya_app/models.dart';

void main() {
  Map<String, dynamic> period({bool measured = true}) => {
    'year': 2026,
    'complete': measured,
    'estimated': false,
    'base_cents': measured ? '0' : null,
    'net_cents': measured ? '0' : null,
    'warnings': measured ? <String>[] : ['MEASUREMENT_GAP'],
    'positions': [
      {
        'register_id': 'i',
        'direction': 'IMPORT',
        'unit': 'kWh',
        'quantity': '0.000000',
        'covered_from': measured ? '2026-01-01' : '',
        'covered_until': measured ? '2026-02-01' : '',
        'cents': measured ? '0' : null,
        'estimated': false,
        'complete': measured,
      },
    ],
  };

  testWidgets(
    'monthly cache distinguishes a measured zero from missing data at small width',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final summary = AnnualSummary.fromJson({
        ...period(),
        'months': [
          {...period(), 'month': 1},
          {...period(measured: false), 'month': 2},
        ],
      });
      expect(summary.months[0].summary.netCents, '0');
      expect(summary.months[1].summary.netCents, isNull);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ListView(children: [CalculatedMonthlyView(summary: summary)]),
          ),
        ),
      );
      await tester.tap(find.text('Berechnete Monatsübersicht'));
      await tester.pumpAndSettle();
      expect(find.text('Januar'), findsOneWidget);
      expect(find.text('Februar'), findsOneWidget);
      expect(find.text('Keine Messdaten'), findsOneWidget);
      expect(find.textContaining('0,00 €'), findsOneWidget);
      await tester.tap(find.text('Januar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('0 kWh'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('older annual responses remain readable without a monthly cache', () {
    expect(AnnualSummary.fromJson(period()).months, isEmpty);
  });
}
