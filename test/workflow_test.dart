import 'navigation_helpers.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meterya_app/api_service.dart';
import 'package:meterya_app/main.dart';
import 'package:meterya_app/repository.dart';
import 'package:meterya_app/view_model.dart';

void main() {
  testWidgets('admin records an exact German decimal and sees history', (
    tester,
  ) async {
    final readings = <Map<String, dynamic>>[];
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      dynamic response;
      if (request.url.path == '/api/v1/me') {
        response = {
          'csrf_token': 'csrf',
          'workspaces': [
            {'id': 'ws', 'name': 'Haushalt', 'role': 'ADMIN'},
          ],
        };
      } else if (request.url.path.endsWith('/transitions')) {
        response = [];
      } else if (request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['value'], '99999999999999.999999');
        expect(body['expected_version'], 1);
        expect(request.headers['X-CSRF-Token'], 'csrf');
        expect(request.headers['Idempotency-Key'], isNotEmpty);
        readings.add({
          'date': body['date'],
          'value': body['value'],
          'register_id': 'register',
        });
        response = {};
      } else {
        response = [
          {
            'id': 'point',
            'name': 'Haus',
            'version': readings.isEmpty ? 1 : 2,
            'meter': {
              'serial': '123',
              'registers': [
                {'id': 'register', 'direction': 'IMPORT', 'unit': 'kWh'},
              ],
            },
            'readings': readings,
          },
        ];
      }
      return http.Response(jsonEncode(response), 200);
    });
    final model = ViewModel(
      Repository(ApiService(client, Uri.parse('http://localhost:8080'))),
    );
    await model.initialize();
    await tester.pumpWidget(MeteryaApp(model: model));
    await tester.pumpAndSettle();
    expect(find.text('Zähler anlegen'), findsNothing);
    await tester.tap(find.byTooltip('Menü öffnen'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ablesung erfassen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ablesung erfassen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manuell'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).last,
      '99999999999999,999999',
    );
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(readings, hasLength(1));
    await tester.tap(find.text('Haus'));
    await tester.pumpAndSettle();
    await selectSection(
      tester,
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
      'Ablesungen',
    );
    await tester.pumpAndSettle();
    expect(find.text('99999999999999,999999 kWh'), findsOneWidget);
    expect(requests.where((r) => r.method == 'POST'), hasLength(1));
    model.dispose();
    client.close();
  });

  testWidgets('user can record readings but cannot create meters', (
    tester,
  ) async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode(
          request.url.path == '/api/v1/me'
              ? {
                  'csrf_token': 'csrf',
                  'workspaces': [
                    {'id': 'ws', 'name': 'Haushalt', 'role': 'USER'},
                  ],
                }
              : [],
        ),
        200,
      ),
    );
    final model = ViewModel(
      Repository(ApiService(client, Uri.parse('http://localhost:8080'))),
    );
    await model.initialize();
    await tester.pumpWidget(MeteryaApp(model: model));
    await tester.pumpAndSettle();
    expect(find.text('Zähler anlegen'), findsNothing);
    expect(find.text('Noch keine Zähler vorhanden.'), findsOneWidget);
    model.dispose();
    client.close();
  });
}
