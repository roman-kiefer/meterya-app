import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meterya_app/api_service.dart';
import 'package:meterya_app/l10n/app_localizations.dart';
import 'package:meterya_app/move_point_dialog.dart';
import 'package:meterya_app/repository.dart';
import 'package:meterya_app/view_model.dart';

void main() {
  for (final blocked in [false, true]) {
    testWidgets(
      blocked
          ? 'linked meter stays in source and displays API explanation'
          : 'move requires destination choice and refreshes source on a small screen',
      (tester) async {
        tester.view.physicalSize = Size(blocked ? 1280 : 390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var moved = false;
        var moves = 0;
        final client = MockClient((request) async {
          if (request.method == 'POST') {
            expect(
              request.url.path,
              '/api/v1/workspaces/source/points/point/move',
            );
            expect(jsonDecode(request.body), {
              'target_workspace_id': 'target',
              'expected_version': 3,
            });
            expect(request.headers['X-CSRF-Token'], 'csrf');
            expect(request.headers['Idempotency-Key'], isNotEmpty);
            moves++;
            if (blocked) return http.Response('{"code":"POINT_LINKED"}', 409);
            moved = true;
            return http.Response('{}', 200);
          }
          if (request.url.path == '/api/v1/me') {
            return http.Response(
              jsonEncode({
                'csrf_token': 'csrf',
                'workspaces': [
                  {'id': 'source', 'name': 'Ausgang', 'role': 'MODERATOR'},
                  {'id': 'target', 'name': 'Ziel', 'role': 'MODERATOR'},
                  {'id': 'readonly', 'name': 'Nur lesen', 'role': 'GUEST'},
                ],
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/points')) {
            return http.Response(
              jsonEncode(
                moved
                    ? []
                    : [
                        {
                          'id': 'point',
                          'name': 'Wasserzähler',
                          'version': 3,
                          'meter': {
                            'serial': 'W-1',
                            'type': 'WATER',
                            'registers': [],
                          },
                          'readings': [],
                        },
                      ],
              ),
              200,
            );
          }
          return http.Response('[]', 200);
        });
        addTearDown(client.close);
        final model = ViewModel(
          Repository(ApiService(client, Uri.parse('http://localhost'))),
        );
        await model.initialize();
        final point = model.points.single;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => MovePointDialog(model: model, point: point),
                  ),
                  child: const Text('Öffnen'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Öffnen'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Verschieben'),
              )
              .onPressed,
          isNull,
        );
        expect(moves, 0);
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        expect(find.text('Nur lesen'), findsNothing);
        expect(find.text('Ausgang'), findsNothing);
        await tester.tap(find.text('Ziel').last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.widgetWithText(FilledButton, 'Verschieben'),
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Verschieben'));
        await tester.pumpAndSettle();
        expect(moves, 1);
        expect(model.workspace?.id, 'source');
        if (blocked) {
          expect(
            find.textContaining('kann nicht einzeln verschoben werden'),
            findsOneWidget,
          );
          expect(model.points.single.id, 'point');
        } else {
          expect(find.byType(MovePointDialog), findsNothing);
          expect(model.points, isEmpty);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
