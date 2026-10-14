import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meterya_app/api_service.dart';
import 'package:meterya_app/main.dart';
import 'package:meterya_app/models.dart';
import 'package:meterya_app/repository.dart';
import 'package:meterya_app/view_model.dart';
import 'navigation_helpers.dart';

void main() {
  for (final width in [360.0, 1280.0]) {
    testWidgets('overview and details stay usable at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = MockClient((_) async => http.Response('[]', 200));
      final model = ViewModel(
        Repository(ApiService(client, Uri.parse('http://localhost'))),
      );
      model.signedIn = true;
      model.workspace = const Workspace('ws', 'Hausanschluss', 'USER');
      model.workspaces = [model.workspace!];
      model.points = [
        Point(
          'p',
          'Hauptzähler',
          '1 ISK00 9851 9295',
          1,
          [
            const Register('i', 'IMPORT', 'kWh'),
            const Register('e', 'EXPORT', 'kWh'),
          ],
          [
            const Reading(
              '2026-10-06',
              '99999999999999.999999',
              'i',
              difference: '1.000001',
            ),
            const Reading('2026-10-01', '99999999999998.999998', 'i'),
            const Reading('2026-10-06', '2.000000', 'e'),
          ],
          consumption: [
            const ConsumptionInterval(
              'i',
              '2026-10-01',
              '2026-10-06',
              '1.000001',
              'kWh',
            ),
          ],
          history: [
            {
              'register_id': 'i',
              'from_year': 2016,
              'until_year': 2020,
              'quantity_mean': '0.000000',
              'cost_mean_cents': '0',
              'rows': [
                {
                  'year': 2020,
                  'complete_year': true,
                  'cost_cents': '0',
                  'position': {
                    'register_id': 'i',
                    'direction': 'IMPORT',
                    'unit': 'kWh',
                    'quantity': '0.000000',
                    'covered_from': '2020-01-01',
                    'covered_until': '2021-01-01',
                    'cents': '0',
                    'estimated': false,
                    'complete': true,
                  },
                },
              ],
            },
          ],
          annual: [
            const AnnualSummary(
              2026,
              false,
              false,
              null,
              null,
              ['UNIT_PRICE_GAP'],
              [
                AnnualPosition(
                  'i',
                  'IMPORT',
                  'kWh',
                  '1.000001',
                  '2026-10-01',
                  '2026-10-06',
                  null,
                  false,
                  false,
                ),
              ],
            ),
            const AnnualSummary(2020, true, false, '0', '0', [], [
              AnnualPosition(
                'i',
                'IMPORT',
                'kWh',
                '0.000000',
                '2020-01-01',
                '2021-01-01',
                '0',
                false,
                true,
              ),
            ]),
          ],
        ),
      ];
      await tester.pumpWidget(MeteryaApp(model: model));
      await tester.pumpAndSettle();
      expect(
        width < 900
            ? find.byTooltip('Menü öffnen')
            : find.byType(NavigationRail),
        findsOneWidget,
      );
      expect(find.text('Verbrauch zwischen Ablesungen'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Hauptzähler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hauptzähler'));
      await tester.pumpAndSettle();
      await selectSection(tester, width, 'Ablesungen');
      // This fixture has one interval, so its difference equals the annual sum.
      expect(find.text('1,000001 kWh'), findsNWidgets(2));
      expect(
        find.byTooltip('Keine vorherige berechnete Ableseperiode verfügbar.'),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
      await selectSection(tester, width, 'Verlauf');
      expect(find.text('2022 – 2026'), findsOneWidget);
      expect(find.textContaining('Keine auswertbaren Daten'), findsWidgets);
      await tester.tap(find.byTooltip('Vorheriges Abrechnungsjahr'));
      await tester.pumpAndSettle();
      expect(find.text('2016 – 2020'), findsOneWidget);
      expect(find.byKey(const ValueKey('bar-i-2020')), findsOneWidget);
      expect(find.text('0,00 kWh'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // An old detail route must not show data after leaving its workspace.
      model.workspace = const Workspace('other', 'OG', 'USER');
      model.workspaces = [model.workspace!];
      model.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('Hauptzähler'), findsNothing);
      expect(find.textContaining('99999999999999'), findsNothing);
      model.dispose();
      client.close();
    });
  }
}
