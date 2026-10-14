import 'navigation_helpers.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meterya_app/api_service.dart';
import 'package:meterya_app/main.dart';
import 'package:meterya_app/models.dart';
import 'package:meterya_app/repository.dart';
import 'package:meterya_app/view_model.dart';

void main() {
  for (final width in [360.0, 1280.0]) {
    testWidgets(
      'own reading correction and retraction confirmation at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final writes = <http.Request>[];
        var current = '20.000000';
        var removed = false;
        var version = 4;
        final client = MockClient((r) async {
          if (r.method == 'POST') {
            writes.add(r);
            version++;
            if (r.url.path.endsWith('/correct')) {
              current = jsonDecode(r.body)['value'] as String;
            } else {
              removed = true;
            }
            return http.Response('{}', 200);
          }
          return http.Response(
            jsonEncode([
              {
                'id': 'p',
                'name': 'Meter',
                'version': version,
                'meter': {
                  'serial': '123',
                  'registers': [
                    {'id': 'i', 'direction': 'IMPORT', 'unit': 'kWh'},
                  ],
                },
                'readings': [
                  if (!removed)
                    {
                      'id': 'own',
                      'register_id': 'i',
                      'date': '2026-01-02',
                      'value': current,
                      'actor': 'user',
                    },
                  {
                    'id': 'foreign',
                    'register_id': 'i',
                    'date': '2026-01-03',
                    'value': '30.000000',
                    'actor': 'other',
                  },
                ],
              },
            ]),
            200,
          );
        });
        final repository = Repository(
          ApiService(client, Uri.parse('http://localhost')),
        );
        repository.subject = 'user';
        repository.api.csrf = 'csrf';
        final model = ViewModel(repository);
        model.signedIn = true;
        model.workspace = const Workspace('w', 'Haus', 'USER');
        model.workspaces = [model.workspace!];
        model.points = await repository.points('w');
        await tester.pumpWidget(MeteryaApp(model: model));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Meter'));
        await tester.tap(find.text('Meter'));
        await tester.pumpAndSettle();
        await selectSection(
          tester,
          tester.view.physicalSize.width / tester.view.devicePixelRatio,
          'Ablesungen',
        );
        await tester.pumpAndSettle();
        expect(find.byTooltip('Ablesung bearbeiten'), findsOneWidget);
        await tester.tap(find.byTooltip('Ablesung bearbeiten'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ablesung korrigieren'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).at(1), '22,000001');
        await tester.enterText(find.byType(TextFormField).at(2), 'Tippfehler');
        await tester.tap(find.text('Speichern'));
        await tester.pumpAndSettle();
        expect(
          writes.single.url.path,
          '/api/v1/workspaces/w/points/p/readings/own/correct',
        );
        expect(jsonDecode(writes.single.body), {
          'expected_version': 4,
          'reason': 'Tippfehler',
          'date': '2026-01-02',
          'value': '22.000001',
        });
        expect(find.text('22,000001 kWh'), findsOneWidget);
        await tester.tap(find.byTooltip('Ablesung bearbeiten'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ablesung zurücknehmen'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Abbrechen'));
        await tester.pumpAndSettle();
        expect(writes.length, 1);
        await tester.tap(find.byTooltip('Ablesung bearbeiten'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ablesung zurücknehmen'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(FilledButton, 'Ablesung zurücknehmen'),
        );
        await tester.pumpAndSettle();
        expect(writes.last.url.path.endsWith('/retract'), true);
        expect(jsonDecode(writes.last.body), {
          'expected_version': 5,
          'reason': '',
        });
        expect(find.text('22,000001 kWh'), findsNothing);
        expect(tester.takeException(), isNull);
        model.dispose();
        client.close();
      },
    );
  }
  testWidgets(
    'version conflict retains correction input and original history',
    (tester) async {
      final client = MockClient(
        (r) async =>
            http.Response('{"code":"AGGREGATE_VERSION_CONFLICT"}', 409),
      );
      final model = ViewModel(
        Repository(ApiService(client, Uri.parse('http://localhost'))),
      );
      model.signedIn = true;
      model.workspace = const Workspace('w', 'Haus', 'ADMIN');
      model.workspaces = [model.workspace!];
      model.points = [
        Point(
          'p',
          'Meter',
          '123',
          4,
          [const Register('i', 'IMPORT', 'kWh')],
          [
            const Reading(
              '2026-01-02',
              '20.000000',
              'i',
              id: 'own',
              actor: 'user',
            ),
          ],
        ),
      ];
      await tester.pumpWidget(MeteryaApp(model: model));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Meter'));
      await tester.pumpAndSettle();
      await selectSection(
        tester,
        tester.view.physicalSize.width / tester.view.devicePixelRatio,
        'Ablesungen',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ablesung bearbeiten'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ablesung korrigieren'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(1), '21');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        '21',
      );
      expect(model.points.single.readings.single.value, '20.000000');
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      model.dispose();
      client.close();
    },
  );
}
