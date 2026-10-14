import 'package:meterya_app/billing_year_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meterya_app/api_service.dart';
import 'package:meterya_app/main.dart';
import 'package:meterya_app/models.dart';
import 'package:meterya_app/repository.dart';
import 'package:meterya_app/view_model.dart';
import 'package:meterya_app/transition_model.dart';
import 'navigation_helpers.dart';

void main() {
  for (final width in [360.0, 1280.0]) {
    testWidgets('meter lifetime and measured dates at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final year = DateTime.now().year;
      final client = MockClient((_) async => http.Response('[]', 200));
      final model =
          ViewModel(
              Repository(ApiService(client, Uri.parse('http://localhost'))),
            )
            ..signedIn = true
            ..workspace = const Workspace('ws', 'Haus', 'ADMIN');
      model.workspaces = [model.workspace!];
      AnnualSummary summary(int y, String from, String until) => AnnualSummary(
        y,
        false,
        false,
        null,
        null,
        ['UNIT_PRICE_GAP'],
        [
          AnnualPosition(
            'reg',
            'IMPORT',
            'kWh',
            '10.000000',
            from,
            until,
            null,
            false,
            false,
          ),
        ],
      );
      model.points = [
        Point(
          'old',
          'Altzähler',
          'old-serial',
          1,
          [const Register('reg', 'IMPORT', 'kWh')],
          [Reading('${year - 1}-01-01', '0', 'reg')],
          archived: true,
          annual: [
            summary(year - 1, '${year - 1}-01-01', '${year - 1}-12-31'),
            summary(year, '$year-01-01', '$year-10-01'),
          ],
        ),
        Point(
          'new',
          'Neuzähler',
          'new-serial',
          1,
          [const Register('reg', 'IMPORT', 'kWh')],
          [Reading('$year-10-01', '0', 'reg')],
          annual: [summary(year, '$year-10-01', '$year-10-06')],
        ),
      ];
      model.meterTransitions = [
        MeterTransition.fromJson({
          'id': 'change',
          'date': '$year-10-01',
          'old_point': 'old',
          'new_points': ['new'],
        }),
      ];
      expect(model.pointsForYear(year + 1).map((p) => p.id), ['new']);
      await tester.pumpWidget(MeteryaApp(model: model));
      await tester.pumpAndSettle();
      expect(find.text('Altzähler'), findsOneWidget);
      expect(find.text('Neuzähler'), findsOneWidget);
      expect(find.text('Erfasst: 01.10.$year–06.10.$year'), findsOneWidget);
      expect(find.textContaining('Unvollständiges Jahr'), findsNothing);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_right),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Vorheriges Abrechnungsjahr'));
      await tester.pumpAndSettle();
      expect(find.text('Neuzähler'), findsNothing);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_left),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Nächstes Abrechnungsjahr'));
      await tester.pumpAndSettle();
      expect(find.text('Neuzähler'), findsOneWidget);
      expect(
        tester.getRect(find.byType(BillingYearPicker)).bottom,
        lessThan(tester.getRect(find.text('Meine Zähler')).top),
      );
      await tester.tap(find.byTooltip('Vorheriges Abrechnungsjahr'));
      await tester.pumpAndSettle();
      expect(find.text('Altzähler'), findsOneWidget);
      expect(find.text('Neuzähler'), findsNothing);
      expect(find.textContaining('Erfasst:'), findsNothing);
      expect(find.text('Vollständiges Jahr'), findsNothing);
      await tester.tap(find.text('Altzähler'));
      await tester.pumpAndSettle();
      expect(
        find.text('Monatsaufteilung & Abrechnungskosten ${year - 1}'),
        findsOneWidget,
      );
      final meterRect = tester.getRect(
        find.byType(DropdownButtonFormField<String>),
      );
      final detailYearRect = tester.getRect(find.byType(BillingYearPicker));
      expect(find.byType(TabBar), findsNothing);
      expect(detailYearRect.bottom, lessThan(meterRect.top));
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_left),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Nächstes Abrechnungsjahr'));
      await tester.pumpAndSettle();
      expect(
        find.text('Monatsaufteilung & Abrechnungskosten $year'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_right),
            )
            .onPressed,
        isNull,
      );
      await selectSection(tester, width, 'Ablesungen');
      await tester.tap(find.byTooltip('Vorheriges Abrechnungsjahr'));
      await tester.pumpAndSettle();
      await selectSection(tester, width, 'Verbrauch & Kosten');
      expect(
        find.text('Monatsaufteilung & Abrechnungskosten ${year - 1}'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      model.dispose();
      client.close();
    });
    testWidgets(
      'simple overview has one action and selects its meter at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
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
        model.signedIn = true;
        model.workspace = const Workspace('ws', 'Haus', 'ADMIN');
        model.workspaces = [model.workspace!];
        model.points = [
          for (final id in ['Z1', 'Z2'])
            Point(
              id,
              id,
              'serial-$id',
              1,
              [
                Register('reg-$id', 'IMPORT', 'kWh'),
                if (id == 'Z2') Register('export-$id', 'EXPORT', 'kWh'),
              ],
              [Reading('2026-10-06', '123.000000', 'reg-$id')],
              annual: [
                AnnualSummary(
                  DateTime.now().year,
                  false,
                  false,
                  '0',
                  id == 'Z2' ? '1234' : null,
                  [],
                  [
                    AnnualPosition(
                      'reg-$id',
                      'IMPORT',
                      'kWh',
                      '12.000000',
                      '${DateTime.now().year}-01-01',
                      '${DateTime.now().year}-10-06',
                      null,
                      false,
                      false,
                    ),
                    if (id == 'Z2')
                      AnnualPosition(
                        'export-$id',
                        'EXPORT',
                        'kWh',
                        '7.000000',
                        '${DateTime.now().year}-01-01',
                        '${DateTime.now().year}-10-06',
                        '1234',
                        false,
                        false,
                      ),
                  ],
                ),
              ],
              tariffs: id == 'Z2'
                  ? const Tariffs([], [
                      Price('2020-01-01', '', 35900, 'IMPORT', ''),
                    ])
                  : null,
            ),
        ];
        await tester.pumpWidget(MeteryaApp(model: model));
        await tester.pumpAndSettle();
        expect(
          find.text('Ablesung erfassen'),
          width < 900 ? findsNothing : findsOneWidget,
        );
        expect(find.text('Z1'), findsOneWidget);
        expect(find.text('Z2'), findsNWidgets(2));
        expect(find.textContaining('Zuletzt abgelesen'), findsNothing);
        expect(find.byType(BillingYearPicker), findsOneWidget);
        expect(find.text('12 kWh'), findsNWidgets(2));
        expect(find.text('7 kWh'), findsOneWidget);
        expect(find.text('12,34 €'), findsOneWidget);
        expect(
          find.text('Verbrauch & Einspeisung ${DateTime.now().year}'),
          findsOneWidget,
        );
        expect(find.text('Kosten ${DateTime.now().year}'), findsOneWidget);
        if (width < 900) {
          await tester.tap(find.byTooltip('Menü öffnen'));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text('Ablesung erfassen'));
        await tester.tap(find.text('Ablesung erfassen'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Manuell'));
        await tester.pumpAndSettle();
        expect(find.text('Welchen Zähler ablesen?'), findsOneWidget);
        await tester.tap(find.text('Z2 · serial-Z2'));
        await tester.pumpAndSettle();
        expect(find.byType(TextFormField), findsWidgets);
        await tester.tap(find.text('Abbrechen'));
        await tester.pumpAndSettle();
        expect(requests, isEmpty);
        expect(tester.takeException(), isNull);
        model.dispose();
        client.close();
      },
    );
  }
}
