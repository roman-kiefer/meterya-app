import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meterya_app/api_service.dart';
import 'package:meterya_app/l10n/app_localizations.dart';
import 'package:meterya_app/models.dart';
import 'package:meterya_app/repository.dart';
import 'package:meterya_app/heat_view.dart';
import 'package:meterya_app/view_model.dart';

void main() {
  test(
    'heat configuration preserves explicit source roles and versions',
    () async {
      late http.Request sent;
      final repo = Repository(
        ApiService(
          MockClient((r) async {
            sent = r;
            return http.Response('{}', 201);
          }),
          Uri.parse('http://localhost:8080/'),
        )..csrf = 'csrf',
      );
      await repo.configureHeat(
        Workspace('ws', 'Hausanschluss', 'ADMIN', version: 4),
        'WP',
        '2026-10-01',
        Point('z1', 'Z1', '9295', 3, const [], const []),
        Point('z2', 'Z2', '9296', 5, const [], const []),
        'key',
      );
      expect(sent.headers['X-CSRF-Token'], 'csrf');
      expect(sent.headers['Idempotency-Key'], 'key');
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['net_point'], 'z1');
      expect(body['house_point'], 'z2');
      expect(body['expected_version'], 4);
      expect(body['expected_point_versions'], {'z1': 3, 'z2': 5});
    },
  );
  testWidgets('USER sees negative balances and cannot configure heat', (
    tester,
  ) async {
    final period = {
      'start_date': '2026-10-01',
      'end_date': '2026-10-06',
      'grid_kwh': '-2.000000',
      'house_pv_kwh': '3.000000',
      'total_kwh': '1.000000',
      'valid': false,
    };
    final repo = Repository(
      ApiService(
        MockClient(
          (r) async => http.Response(
            jsonEncode([
              {
                'id': 'heat',
                'name': 'WP',
                'valid_from': '2026-10-01',
                'net_point': 'z1',
                'house_point': 'z2',
                'flags': ['NEGATIVE_BALANCE'],
                'grid_periods': [],
                'total_periods': [period],
                'yearly': [
                  {
                    'year': 2026,
                    'grid_periods': [],
                    'total_periods': [period],
                    'grid_totals': {},
                    'total_totals': {},
                    'same_coverage': true,
                    'has_gaps': false,
                  },
                ],
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
        Point('z1', 'Z1', '9295', 3, const [], const []),
        Point('z2', 'Z2', '9296', 5, const [], const []),
      ];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HeatView(model: model, manage: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('-2 kWh'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('-2 kWh'), findsOneWidget);
    expect(find.text('1 kWh'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Tarif und Grundpreis von Z1 (netzseitiger Zähler / Z1)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Tarif und Grundpreis von Z1 (netzseitiger Zähler / Z1)'),
      findsOneWidget,
    );
    expect(find.text('Tarife verwalten'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });
}
