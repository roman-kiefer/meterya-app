import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meterya_app/l10n/app_localizations.dart';
import 'package:meterya_app/models.dart';
import 'package:meterya_app/monthly_overview_model.dart';
import 'package:meterya_app/monthly_overview_view.dart';

void main() {
  const import = Register('i', 'IMPORT', 'kWh');
  const export = Register('e', 'EXPORT', 'kWh');
  const positions = [
    AnnualPosition(
      'i',
      'IMPORT',
      'kWh',
      '492.000000',
      '2026-01-01',
      '2026-02-01',
      '15498',
      false,
      true,
    ),
    AnnualPosition(
      'e',
      'EXPORT',
      'kWh',
      '10.000000',
      '2026-01-01',
      '2026-02-01',
      '82',
      false,
      true,
    ),
  ];
  final projected = [
    RegisterOverview.fromJson({
      'register_id': 'i',
      'total_cents': '16748',
      'changing_rate': false,
      'closing': {'register_id': 'i', 'date': '2026-01-31', 'value': '25100'},
      'rate': {
        'valid_from': '2026-01-01',
        'valid_until': '',
        'direction': 'IMPORT',
        'cents': 31500,
      },
    }),
    RegisterOverview.fromJson({
      'register_id': 'e',
      'total_cents': '82',
      'changing_rate': false,
      'rate': {
        'valid_from': '2026-01-01',
        'valid_until': '',
        'direction': 'EXPORT',
        'cents': 8200,
      },
    }),
  ];
  final month = AnnualSummary(
    2026,
    true,
    false,
    '1250',
    '16666',
    [],
    positions,
    overview: projected,
  );
  final annual = AnnualSummary(
    2026,
    false,
    false,
    '1250',
    '16666',
    [],
    positions,
    months: [CalculatedMonth(1, month)],
    overview: projected,
  );
  Point point() => Point(
    'p',
    'Zähler',
    '123',
    1,
    [import, export],
    [
      const Reading('2026-01-31', '25100', 'i'),
      const Reading('2026-02-01', '25101', 'i'),
    ],
    annual: [annual],
    tariffs: const Tariffs([], [
      Price('2026-01-01', '', 31500, 'IMPORT', ''),
      Price('2026-01-01', '', 8200, 'EXPORT', ''),
    ]),
  );

  test('calendar priority and rates preserve exact API amounts', () {
    final rows = MonthlyOverviewModel.rows(point(), annual, import, 2026);
    expect(rows.length, 12);
    expect(rows.first.closing!.value, '25100');
    expect(rows.first.rate!.cents, 31500);
    expect(rows.first.amount, BigInt.from(492000000));
    expect(rows[1].measured, isFalse);
    expect(rows[1].amount, isNull);
    expect(
      MonthlyOverviewModel.heightUnits(rows.first, rows.first.amount!),
      10000,
    );
    // Changing local tariffs must not override the server projection.
    final noProjection = MonthlyOverviewModel.rows(
      point(),
      null,
      import,
      2026,
    ).first;
    expect(noProjection.changingRate, isFalse);
    expect(noProjection.rate, isNull);
  });

  for (final width in [360.0, 1280.0]) {
    testWidgets('monthly charts and tables at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyOverviewView(
                point: point(),
                summary: annual,
                year: 2026,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('25100 kWh'), findsOneWidget);
      expect(find.text('25101 kWh'), findsNothing);
      expect(find.text('167,48 €'), findsNWidgets(2));
      expect(find.text('0,82 €'), findsNothing);
      expect(find.text('Offen'), findsNWidgets(12));
      final bar = tester.getSize(find.byKey(const ValueKey('month-bar-i-1')));
      final open = tester.getSize(find.byKey(const ValueKey('month-bar-i-2')));
      expect(bar.height, greaterThan(open.height));
      await tester.tap(find.widgetWithText(Tab, 'Einspeisung'));
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('25100 kWh'), findsNothing);
      expect(find.text('0,82 €'), findsNWidgets(4));
      expect(find.text('Grundkosten'), findsNothing);
      expect(find.byKey(const ValueKey('month-bar-e-1')), findsOneWidget);
      await tester.tap(find.widgetWithText(Tab, 'Bezug'));
      await tester.pumpAndSettle();
      expect(find.text('25100 kWh'), findsOneWidget);
      final single = Point(
        'single',
        'Strom',
        '456',
        1,
        [import],
        [],
        annual: [annual],
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyOverviewView(
                point: single,
                summary: annual,
                year: 2026,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsNothing);
      expect(find.byType(DataTable), findsOneWidget);
      final closed = AnnualSummary(
        2026,
        true,
        false,
        '15000',
        '200000',
        [],
        positions,
        months: [for (var m = 1; m <= 12; m++) CalculatedMonth(m, month)],
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyOverviewView(
                point: single,
                summary: closed,
                year: 2026,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Offen'), findsNothing);
      expect(find.byKey(const ValueKey('month-bar-i-12')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
