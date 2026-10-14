import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meterya_app/api_service.dart';
import 'package:meterya_app/l10n/app_localizations.dart';
import 'package:meterya_app/models.dart';
import 'package:meterya_app/repository.dart';
import 'package:meterya_app/transition_view.dart';
import 'package:meterya_app/transition_view_model.dart';
import 'package:meterya_app/view_model.dart';

void main() {
  test(
    'transition sends cutoff, both successors and optimistic versions',
    () async {
      final requests = <http.Request>[];
      final repo = Repository(
        ApiService(
          MockClient((r) async {
            requests.add(r);
            return http.Response(jsonEncode(r.method == 'GET' ? [] : {}), 200);
          }),
          Uri.parse('http://localhost:8080/'),
        )..csrf = 'csrf',
      );
      final vm = TransitionViewModel(repo, 'ws');
      final ws = Workspace('ws', 'Hausanschluss', 'ADMIN', version: 4);
      final old = Point(
        'old',
        'Hauptzähler',
        'oldserial',
        3,
        const [],
        const [],
        archived: true,
      );
      final z1 = Point('z1', 'Z1', '9295', 2, const [], const []);
      final z2 = Point('z2', 'Z2', '9296', 2, const [], const []);
      expect(await vm.save(ws, old, [z1, z2], '2026-10-01', 'key'), true);
      final request = requests.first;
      expect(request.headers['X-CSRF-Token'], 'csrf');
      expect(request.headers['Idempotency-Key'], 'key');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['old_point'], 'old');
      expect(body['new_points'], ['z1', 'z2']);
      expect(body['date'], '2026-10-01');
      expect(body['expected_version'], 4);
      expect(body['expected_point_versions'], {'old': 3, 'z1': 2, 'z2': 2});
    },
  );
  testWidgets('USER can read transition history without administrative form', (
    tester,
  ) async {
    final repo = Repository(
      ApiService(
        MockClient(
          (r) async => http.Response(
            jsonEncode([
              {
                'id': 't',
                'date': '2026-10-01',
                'old_point': 'old',
                'new_points': ['z1', 'z2'],
              },
            ]),
            200,
          ),
        ),
        Uri.parse('http://localhost:8080/'),
      ),
    );
    final model = ViewModel(repo)
      ..signedIn = true
      ..workspace = Workspace('ws', 'Hausanschluss', 'USER')
      ..points = [
        Point(
          'old',
          'Hauptzähler',
          'oldserial',
          3,
          const [],
          const [],
          archived: true,
        ),
        Point('z1', 'Z1', '9295', 2, const [], const []),
        Point('z2', 'Z2', '9296', 2, const [], const []),
      ];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TransitionView(model: model),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hauptzähler → Z1, Z2'), findsOneWidget);
    expect(find.text('Zählerwechsel festhalten'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });
}
