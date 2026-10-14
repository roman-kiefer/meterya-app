import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meterya_app/api_service.dart';
import 'package:meterya_app/l10n/app_localizations.dart';
import 'package:meterya_app/models.dart';
import 'package:meterya_app/point_costs_view.dart';
import 'package:meterya_app/repository.dart';
import 'package:meterya_app/view_model.dart';

void main() {
  testWidgets(
    'monthly view preserves warnings and exact amounts without duplicate reports',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <http.Request>[];
      final client = MockClient((r) async {
        requests.add(r);
        return http.Response('[]', 200);
      });
      final model = ViewModel(
        Repository(ApiService(client, Uri.parse('http://localhost'))),
      );
      AnnualSummary summary(int year, {bool missing = false}) {
        final position = AnnualPosition(
          'i',
          'IMPORT',
          'kWh',
          missing ? '99999999999999.999999' : '0.000000',
          '$year-01-01',
          '$year-02-01',
          missing ? null : '12345',
          missing,
          true,
        );
        final month = AnnualSummary(
          year,
          false,
          missing,
          missing ? null : '0',
          missing ? null : '12345',
          missing ? ['UNIT_PRICE_GAP'] : [],
          [position],
        );
        return AnnualSummary(
          year,
          false,
          missing,
          month.baseCents,
          month.netCents,
          month.warnings,
          [position],
          months: [CalculatedMonth(1, month)],
        );
      }

      final point = Point(
        'p',
        'Haus',
        '123',
        1,
        [const Register('i', 'IMPORT', 'kWh')],
        [],
        annual: [summary(2026, missing: true), summary(2025)],
      );
      Widget view(int year) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PointCostsView(model: model, point: point, year: year),
        ),
      );
      await tester.pumpWidget(view(2026));
      await tester.pumpAndSettle();
      expect(
        find.text('Monatsaufteilung & Abrechnungskosten 2026'),
        findsOneWidget,
      );
      expect(find.text('99999999999999,999999 kWh'), findsWidgets);
      expect(find.text('Zeitanteilig geschätzt'), findsWidgets);
      expect(
        find.text(
          AppLocalizations.of(
            tester.element(find.byType(PointCostsView)),
          ).unitPriceGap,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Kosten abzüglich Einspeiseerlös: —'),
        findsOneWidget,
      );
      expect(find.byType(ExpansionTile), findsNothing);
      expect(
        find.text('Unvollständiges Jahr · nur vorhandene Zeiträume'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(view(2025));
      await tester.pumpAndSettle();
      expect(find.text('Zeitanteilig geschätzt'), findsNothing);
      expect(find.text('99999999999999,999999 kWh'), findsNothing);
      expect(find.text('0 kWh'), findsWidgets);
      expect(find.text('123,45 €'), findsWidgets);
      expect(
        find.textContaining('Kosten abzüglich Einspeiseerlös: 123,45 €'),
        findsOneWidget,
      );
      expect(find.byType(ExpansionTile), findsNothing);
      expect(requests, isEmpty);
      expect(tester.takeException(), isNull);
      model.dispose();
      client.close();
    },
  );
}
