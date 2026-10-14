import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meterya_app/l10n/app_localizations.dart';
import 'package:meterya_app/models.dart';
import 'package:meterya_app/year_comparison_model.dart';
import 'package:meterya_app/year_comparison_view.dart';

Point fixture() => Point(
  'p',
  'Haus',
  '123',
  1,
  [const Register('i', 'IMPORT', 'kWh'), const Register('e', 'EXPORT', 'kWh')],
  [],
  history: [
    for (final id in ['i', 'e'])
      {
        'register_id': id,
        'from_year': 2022,
        'until_year': 2026,
        'quantity_mean': id == 'i' ? '50000000000000.000000' : '3.000000',
        'cost_mean_cents': id == 'i' ? '0' : '24',
        'rows': [
          for (final year in [2025, 2026])
            {
              'year': year,
              'complete_year': year == 2025,
              'cost_cents': id == 'i' ? null : (year == 2025 ? '32' : '16'),
              'position': {
                'register_id': id,
                'direction': id == 'i' ? 'IMPORT' : 'EXPORT',
                'unit': 'kWh',
                'quantity': id == 'i'
                    ? (year == 2025 ? '0.000000' : '99999999999999.999999')
                    : (year == 2025 ? '4.000000' : '2.000000'),
                'covered_from': '$year-01-01',
                'covered_until': year == 2025 ? '2026-01-01' : '2026-10-01',
                'cents': null,
                'estimated': year == 2026,
                'complete': year == 2025,
              },
            },
        ],
      },
  ],
  annual: [
    const AnnualSummary(2026, false, true, null, null, [], [
      AnnualPosition(
        'i',
        'IMPORT',
        'kWh',
        '99999999999999.999999',
        '2026-01-01',
        '2026-10-01',
        null,
        true,
        false,
      ),
      AnnualPosition(
        'e',
        'EXPORT',
        'kWh',
        '2.000000',
        '2026-01-01',
        '2026-10-01',
        '16',
        true,
        false,
      ),
    ]),
    const AnnualSummary(2025, true, false, '0', '0', [], [
      AnnualPosition(
        'i',
        'IMPORT',
        'kWh',
        '0.000000',
        '2025-01-01',
        '2026-01-01',
        '0',
        false,
        true,
      ),
      AnnualPosition(
        'e',
        'EXPORT',
        'kWh',
        '4.000000',
        '2025-01-01',
        '2026-01-01',
        '32',
        false,
        true,
      ),
    ]),
    const AnnualSummary(2024, false, false, null, null, [], [
      AnnualPosition(
        'i',
        'IMPORT',
        'kWh',
        '0.000000',
        '',
        '',
        null,
        false,
        false,
      ),
    ]),
  ],
);

void main() {
  test(
    'chart normalization is exact and separates register scales and missing coverage',
    () {
      final point = fixture();
      final imports = YearComparisonModel.window(point, 'i', 2026);
      expect(imports.map((r) => r.year), [2022, 2023, 2024, 2025, 2026]);
      expect(imports.take(3).every((r) => r.amount == null), isTrue);
      expect(imports[3].amount, BigInt.zero);
      expect(imports[3].widthUnits, 0);
      expect(imports[4].amount, BigInt.parse('99999999999999999999'));
      expect(imports[4].widthUnits, 10000);
      final exports = YearComparisonModel.window(point, 'e', 2026);
      expect(exports[3].widthUnits, 10000);
      expect(exports[4].widthUnits, 5000);
      expect(exports[4].position!.complete, isFalse);
      expect(exports[4].position!.estimated, isTrue);
    },
  );

  testWidgets(
    'narrow chart shows partial periods and zero without drawing missing years',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: YearComparisonView(point: fixture(), lastYear: 2026),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bezug'), findsOneWidget);
      expect(find.text('Einspeisung'), findsOneWidget);
      expect(find.text('2024 · Keine auswertbaren Daten'), findsOneWidget);
      expect(find.textContaining('0,00 kWh'), findsWidgets);
      expect(find.text('2026 (01.01. - 01.10.)'), findsOneWidget);
      expect(find.textContaining('Erfasst:'), findsNothing);
      expect(find.text('Zeitanteilig geschätzt'), findsOneWidget);
      expect(find.byKey(const ValueKey('bar-i-2024')), findsNothing);
      expect(find.textContaining('100000000000000,00 kWh'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byKey(const ValueKey('bar-i-2025')),
            )
            .value,
        0,
      );
      await tester.ensureVisible(find.widgetWithText(Tab, 'Einspeisung'));
      await tester.tap(find.widgetWithText(Tab, 'Einspeisung'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byKey(const ValueKey('bar-e-2026')),
            )
            .value,
        0.5,
      );
      expect(find.textContaining('100000000000000,00 kWh'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
