import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meterya_app/api_service.dart';
import 'package:meterya_app/billing_view.dart';
import 'package:meterya_app/l10n/app_localizations.dart';
import 'package:meterya_app/models.dart';
import 'package:meterya_app/repository.dart';
import 'package:meterya_app/tariff_view.dart';
import 'package:meterya_app/tariff_view_model.dart';
import 'package:meterya_app/view_model.dart';

Widget localized(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  test('prices and large annual money remain exact', () {
    expect(parsePrice('0,082', base: false), 8200);
    expect(parsePrice('0.00001', base: false), 1);
    expect(parsePrice('120,00', base: true), 12000);
    expect(parsePrice('0', base: true), 0);
    expect(parsePrice('0.001', base: true), isNull);
    for (final input in ['-1', '1e3', '0.000001', '1.000,2', '99999999999']) {
      expect(parsePrice(input, base: false), isNull);
    }
    expect(displayUnitPrice(8200), '0,082');
    expect(displayEuros('1234567890123456789'), '12345678901234567,89 €');
    expect(displayEuros('-1'), '−0,01 €');
  });

  test('tariff draft rejects overlap without changing existing prices', () {
    final client = MockClient((_) async => http.Response('{}', 200));
    final home = ViewModel(
      Repository(ApiService(client, Uri.parse('http://localhost:8080'))),
    );
    final p = Point('p', 'Haus', '123', 1, [
      const Register('r', 'IMPORT', 'kWh'),
    ], []);
    final draft = TariffViewModel(home, p);
    expect(draft.add('IMPORT', '', '2026-01-01', '2026-02-01', '0,31'), isTrue);
    expect(draft.add('IMPORT', '', '2026-01-31', '', '0,4'), isFalse);
    expect(draft.error, 'TARIFF_OVERLAP');
    expect(draft.prices, hasLength(1));
    expect(draft.add('IMPORT', '', '2026-02-01', '', '0,4'), isTrue);
    expect(draft.add('BASE', 'MONTH', '2026-02-30', '', '12'), isFalse);
    draft.dispose();
    home.dispose();
    client.close();
  });

  testWidgets(
    'partial annual bill separates export and does not show unknown as zero',
    (tester) async {
      final p = Point(
        'p',
        'Haus',
        '123',
        3,
        [],
        [],
        annual: [
          const AnnualSummary(
            2026,
            false,
            true,
            '100',
            null,
            ['MEASUREMENT_GAP', 'UNIT_PRICE_GAP'],
            [
              AnnualPosition(
                'i',
                'IMPORT',
                'kWh',
                '24.000000',
                '2026-10-04',
                '2026-10-05',
                null,
                true,
                false,
              ),
              AnnualPosition(
                'e',
                'EXPORT',
                'kWh',
                '0.000000',
                '',
                '',
                null,
                false,
                false,
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        localized(SingleChildScrollView(child: BillingView(point: p))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jahresübersicht und Kosten'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Zeitanteilig geschätzt'), findsOneWidget);
      expect(find.text('Bezug: 24 kWh'), findsOneWidget);
      expect(find.text('Einspeisung: 0 kWh'), findsNothing);
      expect(find.text('Einspeiseerlös (wird abgezogen)'), findsOneWidget);
      expect(find.text('Noch nicht berechenbar'), findsNWidgets(3));
      expect(find.text('0,00 €'), findsNothing);
      expect(find.text('1,00 €'), findsOneWidget);
    },
  );

  testWidgets(
    'admin saves euro tariff with cents per thousand and expected version',
    (tester) async {
      Map<String, dynamic>? saved;
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          expect(request.url.path, '/api/v1/workspaces/ws/points/p/tariffs');
          expect(request.headers['X-CSRF-Token'], 'csrf');
          expect(request.headers['Idempotency-Key'], isNotEmpty);
          saved = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{}', 200);
        }
        return http.Response('[]', 200);
      });
      final api = ApiService(client, Uri.parse('http://localhost:8080'))
        ..csrf = 'csrf';
      final home = ViewModel(Repository(api))
        ..workspace = const Workspace('ws', 'Haushalt', 'ADMIN');
      final p = Point('p', 'Haus', '123', 7, [
        const Register('r', 'IMPORT', 'kWh'),
      ], []);
      await tester.pumpWidget(localized(TariffDialog(model: home, point: p)));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bezug').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('price-from')), '2026-01-01');
      await tester.enterText(find.byKey(const Key('price-amount')), '0,082');
      // Saving also accepts the pending input, avoiding silently discarded prices.
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(saved?['expected_version'], 7);
      final tariffs = saved?['tariffs'] as Map<String, dynamic>;
      expect((tariffs['unit_prices'] as List).single['cents'], 8200);
      expect((tariffs['unit_prices'] as List).single['direction'], 'IMPORT');
      home.dispose();
      client.close();
    },
  );
}
