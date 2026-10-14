import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:meterya_app/l10n/app_localizations.dart';
import 'package:meterya_app/year_trend_barometer.dart';
import 'package:meterya_app/models.dart';
import 'package:meterya_app/year_comparison_model.dart';

AnnualPosition position(
  int year,
  String quantity, {
  int? month,
  bool partial = false,
  String register = 'i',
}) {
  final from = DateTime(year, month ?? 1).toIso8601String().substring(0, 10);
  final until =
      (month == null
              ? DateTime(year, partial ? 4 : 13)
              : DateTime(year, month + (partial ? 0 : 1), partial ? 10 : 1))
          .toIso8601String()
          .substring(0, 10);
  return AnnualPosition(
    register,
    register == 'i' ? 'IMPORT' : 'EXPORT',
    'kWh',
    quantity,
    from,
    until,
    null,
    false,
    !partial,
  );
}

Point fixture({bool missing = false, bool zero = false}) => Point(
  'p',
  'Meter',
  'serial',
  1,
  [const Register('i', 'IMPORT', 'kWh'), const Register('e', 'EXPORT', 'kWh')],
  [],
  history: [
    {
      'register_id': 'i',
      'from_year': 2022,
      'until_year': 2026,
      'trend_count': 2,
      'trend_direction': -1,
      'trend_percent': '-15.00',
      'rows': [
        {
          'year': 2026,
          'change': {
            'percent': '-50.00',
            'months': [1, 2],
            'estimated': false,
          },
        },
      ],
    },
  ],
  annual: [
    AnnualSummary(2024, true, false, null, null, [], [position(2024, '1000')]),
    AnnualSummary(
      2025,
      true,
      false,
      null,
      null,
      [],
      [position(2025, zero ? '0' : '1200')],
      months: [
        CalculatedMonth(
          1,
          AnnualSummary(2025, true, false, null, null, [], [
            position(2025, zero ? '0' : '100', month: 1),
          ]),
        ),
        if (!missing)
          CalculatedMonth(
            2,
            AnnualSummary(2025, true, false, null, null, [], [
              position(2025, zero ? '0' : '200', month: 2),
            ]),
          ),
      ],
    ),
    AnnualSummary(
      2026,
      false,
      false,
      null,
      null,
      [],
      [position(2026, '180', partial: true)],
      months: [
        CalculatedMonth(
          1,
          AnnualSummary(2026, true, false, null, null, [], [
            position(2026, '50', month: 1),
          ]),
        ),
        CalculatedMonth(
          2,
          AnnualSummary(2026, true, false, null, null, [], [
            position(2026, '100', month: 2),
          ]),
        ),
        CalculatedMonth(
          3,
          AnnualSummary(2026, false, false, null, null, [], [
            position(2026, '30', month: 3, partial: true),
          ]),
        ),
      ],
    ),
  ],
);

void main() {
  test('missing API projection is unavailable without local fallback', () {
    expect(HistoryTrend.window(fixture(), 'e', 2026).percent, isNull);
    expect(HistoryTrend.window(fixture(), 'i', 2030).percent, isNull);
    expect(YearOnYearComparison.forYear(fixture(), 'i', 2025), isNull);
  });
  testWidgets('barometer renders known trend on small screen', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: YearTrendBarometer(
              trend: HistoryTrend.window(fixture(), 'i', 2026),
              color: Colors.teal,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('-15,00 %'), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byKey(const ValueKey('trend-direction'))).icon,
      Icons.trending_down,
    );
    expect(tester.takeException(), isNull);
  });
  test('history quantity display rounds exactly to two decimals', () {
    expect(YearComparisonModel.formatQuantity('3707.666667'), '3707,67');
    expect(YearComparisonModel.formatQuantity('2196'), '2196,00');
    expect(YearComparisonModel.formatQuantity('0.004999'), '0,00');
    expect(YearComparisonModel.formatQuantity('0.005000'), '0,01');
    expect(
      YearComparisonModel.formatQuantity('99999999999999.999999'),
      '100000000000000,00',
    );
  });
}
