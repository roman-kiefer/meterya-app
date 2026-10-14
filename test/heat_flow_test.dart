import 'package:meterya_app/heat_details_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meterya_app/app_theme.dart';
import 'package:meterya_app/heat_flow_view.dart';
import 'package:meterya_app/heat_model.dart';
import 'package:meterya_app/l10n/app_localizations.dart';
import 'package:meterya_app/models.dart';

void main() {
  for (final width in [360.0, 1000.0]) {
    testWidgets(
      'compact period tables preserve invalid rows and valid sums at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final periods = [
          HeatPeriod.fromJson({
            'start_date': '2026-10-01',
            'end_date': '2026-10-06',
            'grid_kwh': '26',
            'house_pv_kwh': '6',
            'total_kwh': '32',
            'valid': true,
          }),
          HeatPeriod.fromJson({
            'start_date': '2026-10-06',
            'end_date': '2026-10-07',
            'grid_kwh': '-2',
            'house_pv_kwh': '3',
            'total_kwh': '1',
            'valid': false,
          }),
        ];
        await tester.pumpWidget(
          MaterialApp(
            theme: meteryaTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: HeatPeriodTable(
                  periods: periods,
                  total: true,
                  sums: HeatPeriodTotals.fromJson({
                    'days': 5,
                    'grid_kwh': '26',
                    'house_pv_kwh': '6',
                    'total_kwh': '32',
                  }),
                ),
              ),
            ),
          ),
        );
        expect(find.text('-2 kWh'), findsOneWidget);
        expect(find.text('26 kWh'), findsNWidgets(2));
        expect(find.text('32 kWh'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final width in [360.0, 1000.0]) {
    testWidgets(
      'heat flow preserves values and handles missing years at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final report = HeatReport.fromJson({
          'id': 'wp',
          'name': 'WP',
          'valid_from': '2026-10-01',
          'net_point': 'z1',
          'house_point': 'z2',
          'flags': [],
          'yearly': [
            {
              'year': 2026,
              'covered_from': '2026-10-01',
              'covered_until': '2026-10-07',
              'same_coverage': true,
              'has_gaps': false,
              'grid_share_per_mille': 736,
              'pv_share_per_mille': 264,
              'grid_totals': {'days': 6, 'grid_kwh': '19.500000'},
              'total_totals': {
                'days': 6,
                'grid_kwh': '19.500000',
                'house_pv_kwh': '7.000000',
                'total_kwh': '26.500000',
              },
            },
          ],
          'grid_periods': [],
          'total_periods': [
            {
              'start_date': '2026-10-01',
              'end_date': '2026-10-06',
              'grid_kwh': '15.500000',
              'house_pv_kwh': '5.000000',
              'total_kwh': '20.500000',
              'valid': true,
            },
            {
              'start_date': '2026-10-06',
              'end_date': '2026-10-07',
              'grid_kwh': '4',
              'house_pv_kwh': '2',
              'total_kwh': '6',
              'valid': true,
            },
          ],
        });
        Future<void> show(int year) => tester.pumpWidget(
          MaterialApp(
            theme: meteryaTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: HeatFlowView(
                    report: report,
                    year: year,
                    net: Point('z1', 'Z1', '9295', 1, [], []),
                    house: Point('z2', 'Z2', '9296', 1, [], []),
                  ),
                ),
              ),
            ),
          ),
        );
        await show(2026);
        expect(find.text('Virtueller Zähler'.toUpperCase()), findsNothing);

        expect(find.text('19,5 kWh'), findsOneWidget);
        expect(find.text('7 kWh'), findsOneWidget);
        expect(find.text('26,5 kWh'), findsOneWidget);
        expect(find.text('73,6 %'), findsOneWidget);
        expect(find.text('26,4 %'), findsOneWidget);
        expect(find.text('01.10.2026 – 07.10.2026'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await show(2025);
        expect(find.text('26,5 kWh'), findsNothing);
        expect(find.text('—'), findsNWidgets(3));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
