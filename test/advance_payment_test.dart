import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meterya_app/advance_payment_view.dart';
import 'package:meterya_app/api_service.dart';
import 'package:meterya_app/l10n/app_localizations.dart';
import 'package:meterya_app/main.dart';
import 'package:meterya_app/models.dart';
import 'package:meterya_app/report.dart';
import 'package:meterya_app/repository.dart';
import 'package:meterya_app/view_model.dart';

Map<String, dynamic> pointJson({
  String type = 'ELECTRICITY',
  List<Map<String, dynamic>> advance = const [],
  int version = 3,
}) => {
  'id': 'point',
  'name': 'Haus',
  'version': version,
  'archived': false,
  'meter': {
    'serial': '123',
    'type': type,
    'registers': [
      {'id': 'reg', 'direction': 'IMPORT', 'unit': 'kWh'},
    ],
  },
  'readings': [],
  'advance_payments': ?(advance.isEmpty ? null : advance),
};

AnnualSummary summary({
  String? net = '150000',
  String? paid = '147516',
  String? balance = '2484',
  bool complete = true,
}) => AnnualSummary(
  2026,
  complete,
  false,
  '0',
  net,
  const [],
  const [],
  pointVersion: 1,
  calculationVersion: 4,
  advancePaymentCents: paid,
  estimatedBalanceCents: balance,
);

Widget app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: ListView(children: [child])),
);

ViewModel offlineModel() => ViewModel(
  Repository(
    ApiService(
      MockClient((_) async => http.Response('[]', 200)),
      Uri.parse('http://localhost'),
    ),
  ),
);

void main() {
  test('parses the schedule, meter type and estimate fields', () {
    final point = Point.fromJson(
      pointJson(
        advance: [
          {'valid_from': '2026-08-15', 'cents': 11500},
          {'valid_from': '2026-01-01', 'cents': 12356},
        ],
      ),
    );
    expect(point.meterType, 'ELECTRICITY');
    expect(point.supportsAdvancePayments, isTrue);
    expect(point.advancePayments.map((a) => a.from), [
      '2026-01-01',
      '2026-08-15',
    ]);
    expect(point.advancePayments.first.toJson(), {
      'valid_from': '2026-01-01',
      'cents': 12356,
    });
    expect(
      Point.fromJson(pointJson(type: 'BIDIRECTIONAL')).supportsAdvancePayments,
      isTrue,
    );
    expect(
      Point.fromJson(pointJson(type: 'WATER')).supportsAdvancePayments,
      isFalse,
    );
    expect(
      Point.fromJson({
        ...pointJson(),
        'kind': 'VIRTUAL',
      }).supportsAdvancePayments,
      isFalse,
    );
    expect(Point.fromJson(pointJson()).advancePayments, isEmpty);
    final parsed = AnnualSummary.fromJson({
      'year': 2026,
      'complete': true,
      'estimated': false,
      'base_cents': '0',
      'net_cents': '150000',
      'warnings': [],
      'positions': [],
      'advance_payment_cents': '147516',
      'estimated_balance_cents': '2484',
    });
    expect(parsed.advancePaymentCents, '147516');
    expect(parsed.estimatedBalanceCents, '2484');
    final legacy = AnnualSummary.fromJson({
      'year': 2026,
      'complete': true,
      'estimated': false,
      'base_cents': null,
      'net_cents': null,
      'warnings': [],
      'positions': [],
    });
    expect(legacy.advancePaymentCents, isNull);
    expect(legacy.estimatedBalanceCents, isNull);
  });

  test(
    'draft adds, replaces, validates, removes and saves the schedule',
    () async {
      final model = offlineModel();
      final point = Point.fromJson(
        pointJson(
          advance: [
            {'valid_from': '2026-01-01', 'cents': 12356},
          ],
        ),
      );
      List<AdvancePayment>? saved;
      String? savedKey;
      final draft = AdvancePaymentViewModel(
        model,
        point,
        onSave: (schedule, key) async {
          saved = schedule;
          savedKey = key;
        },
      );
      final firstKey = draft.key;
      expect(draft.add('2026-08-15', '115'), isTrue);
      expect(draft.add('2026-05-01', '132,65'), isTrue);
      expect(draft.key, isNot(firstKey));
      expect(draft.entries.map((e) => e.from), [
        '2026-01-01',
        '2026-05-01',
        '2026-08-15',
      ]);
      expect(draft.add('2026-01-01', '120.00'), isTrue);
      expect(draft.entries.first.cents, 12000);
      expect(draft.entries, hasLength(3));
      for (final (date, amount) in [
        ('2026-02-30', '1'),
        ('2026-1-01', '1'),
        ('1899-12-31', '1'),
        ('2026-03-01', '-1'),
        ('2026-03-01', '1,234'),
      ]) {
        expect(draft.add(date, amount), isFalse, reason: '$date $amount');
        expect(draft.error, 'INVALID_ADVANCE_PAYMENT');
      }
      draft.remove(draft.entries.last);
      expect(draft.error, isNull);
      expect(await draft.save(), isTrue);
      expect(saved!.map((e) => (e.from, e.cents)), [
        ('2026-01-01', 12000),
        ('2026-05-01', 13265),
      ]);
      expect(savedKey, draft.key);

      final failing = AdvancePaymentViewModel(
        model,
        point,
        onSave: (_, _) async =>
            throw const ApiException('ADVANCE_PAYMENT_DUPLICATE'),
      );
      expect(await failing.save(), isFalse);
      expect(failing.error, 'ADVANCE_PAYMENT_DUPLICATE');
      draft.dispose();
      failing.dispose();
      model.dispose();
    },
  );

  testWidgets('dialog saves a schedule with a mid-month change', (
    tester,
  ) async {
    final model = offlineModel();
    final point = Point.fromJson(pointJson());
    List<AdvancePayment>? saved;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AdvancePaymentDialog(
                model: model,
                point: point,
                onSave: (schedule, _) async => saved = schedule,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Noch keine Abschläge hinterlegt.'), findsOneWidget);
    for (final (date, amount) in [
      ('2026-01-01', '123,56'),
      ('2026-05-01', '132,65'),
    ]) {
      await tester.enterText(find.byKey(const Key('advance-from')), date);
      await tester.enterText(find.byKey(const Key('advance-amount')), amount);
      await tester.tap(find.byKey(const Key('advance-add')));
      await tester.pumpAndSettle();
    }
    expect(find.text('123,56 € pro Monat'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('advance-amount')), 'x');
    await tester.tap(find.byKey(const Key('advance-add')));
    await tester.pumpAndSettle();
    expect(find.textContaining('gültiges Startdatum'), findsOneWidget);
    // A pending entry is added when saving, like the tariff dialog does.
    await tester.enterText(find.byKey(const Key('advance-from')), '2026-08-15');
    await tester.enterText(find.byKey(const Key('advance-amount')), '115');
    await tester.tap(find.byKey(const Key('advance-save')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(saved!.map((e) => (e.from, e.cents)), [
      ('2026-01-01', 12356),
      ('2026-05-01', 13265),
      ('2026-08-15', 11500),
    ]);
    model.dispose();
  });

  testWidgets('balance card distinguishes remaining payment, credit and zero', (
    tester,
  ) async {
    Future<String> amountFor(AnnualSummary value) async {
      await tester.pumpWidget(app(AdvanceBalanceCard(summary: value)));
      await tester.pumpAndSettle();
      expect(find.text('Abschläge und geschätzter Saldo 2026'), findsOneWidget);
      expect(
        find.textContaining('keine Abrechnung des Versorgers'),
        findsOneWidget,
      );
      return tester
          .widget<Text>(find.byKey(const Key('advance-balance-amount')))
          .data!;
    }

    expect(await amountFor(summary()), '24,84 €');
    expect(find.text('Geschätzte Nachzahlung'), findsOneWidget);
    expect(find.text('1500,00 €'), findsOneWidget);
    expect(find.text('1475,16 €'), findsOneWidget);

    expect(
      await amountFor(
        summary(net: '120000', paid: '147516', balance: '-27516'),
      ),
      '275,16 €',
    );
    expect(find.text('Geschätztes Guthaben'), findsOneWidget);

    expect(
      await amountFor(summary(net: '120000', paid: '120000', balance: '0')),
      '0,00 €',
    );
    expect(find.text('Geschätzt ausgeglichen'), findsOneWidget);

    await amountFor(summary(complete: false));
    expect(find.textContaining('Teilkosten'), findsOneWidget);
    expect(find.textContaining('unvollständig'), findsOneWidget);

    expect(await amountFor(summary(net: null, balance: null)), '—');
    expect(find.text('Geschätzter Saldo'), findsOneWidget);
    expect(find.textContaining('Bitte Tarife hinterlegen'), findsOneWidget);

    await tester.pumpWidget(
      app(AdvanceBalanceCard(summary: summary(paid: null, balance: null))),
    );
    expect(find.byKey(const Key('advance-balance')), findsNothing);
  });

  testWidgets('english labels', (tester) async {
    tester.binding.platformDispatcher.localesTestValue = const [Locale('en')];
    await tester.pumpWidget(app(AdvanceBalanceCard(summary: summary())));
    await tester.pumpAndSettle();
    expect(find.text('Estimated remaining payment'), findsOneWidget);
    expect(find.text('24.84 €'), findsOneWidget);
    expect(find.textContaining('not a final bill'), findsOneWidget);
  });

  test('report contains advance payments and the estimated balance', () {
    final point = Point(
      'point',
      'Haus',
      '123',
      1,
      [const Register('reg', 'IMPORT', 'kWh')],
      [],
      meterType: 'ELECTRICITY',
    );
    final report = BillingReport(
      const Workspace('ws', 'Haushalt', 'ADMIN'),
      point,
      summary(),
      DateTime.utc(2026, 11, 6),
    );
    final l = lookupAppLocalizations(const Locale('de'));
    final data =
        jsonDecode(report.render(ReportFormat.json, l).content)
            as Map<String, dynamic>;
    expect(data['advance_payment_cents'], '147516');
    expect(data['estimated_balance_cents'], '2484');
    final html = report.render(ReportFormat.html, l).content;
    expect(html, contains('Geschätzte Nachzahlung'));
    expect(html, contains('24,84 €'));
    expect(html, contains('keine Abrechnung des Versorgers'));
  });

  group('settings', () {
    Future<(List<http.Request>, ViewModel)> open(
      WidgetTester tester, {
      String role = 'ADMIN',
      String type = 'ELECTRICITY',
    }) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var version = 3;
      var advance = <Map<String, dynamic>>[];
      final requests = <http.Request>[];
      final client = MockClient((r) async {
        requests.add(r);
        dynamic response;
        if (r.method == 'POST') {
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          expect(
            r.url.path,
            '/api/v1/workspaces/ws/points/point/advance-payments',
          );
          expect(body['expected_version'], version);
          advance = (body['advance_payments'] as List)
              .cast<Map<String, dynamic>>();
          version++;
          response = {};
        } else if (r.url.path == '/api/v1/me') {
          response = {
            'csrf_token': 'csrf',
            'workspaces': [
              {'id': 'ws', 'name': 'Haushalt', 'version': 1, 'role': role},
            ],
          };
        } else if (r.url.path.endsWith('/members')) {
          response = {'version': 1, 'members': []};
        } else if (r.url.path.endsWith('/invitations') ||
            r.url.path.endsWith('/power-to-heat') ||
            r.url.path.endsWith('/transitions')) {
          response = [];
        } else {
          response = [
            pointJson(type: type, advance: advance, version: version),
          ];
        }
        return http.Response(jsonEncode(response), 200);
      });
      final model = ViewModel(
        Repository(ApiService(client, Uri.parse('http://localhost:8080'))),
      );
      addTearDown(model.dispose);
      await model.initialize();
      await tester.pumpWidget(MeteryaApp(model: model));
      await tester.pumpAndSettle();
      return (requests, model);
    }

    Future<void> openMeters(WidgetTester tester) async {
      await tester.tap(find.text('Einstellungen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zähler & Tarife'));
      await tester.pumpAndSettle();
    }

    testWidgets('admins manage the schedule of electricity meters', (
      tester,
    ) async {
      final (requests, model) = await open(tester);
      await openMeters(tester);
      await tester.ensureVisible(find.text('Abschläge verwalten'));
      await tester.tap(find.text('Abschläge verwalten'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('advance-from')),
        '2026-08-15',
      );
      await tester.enterText(find.byKey(const Key('advance-amount')), '115');
      await tester.tap(find.byKey(const Key('advance-save')));
      await tester.pumpAndSettle();
      final post = requests.singleWhere((r) => r.method == 'POST');
      expect(jsonDecode(post.body)['advance_payments'], [
        {'valid_from': '2026-08-15', 'cents': 11500},
      ]);
      expect(post.headers['Idempotency-Key'], isNotEmpty);
      expect(model.points.single.advancePayments.single.cents, 11500);
      await tester.tap(find.text('Abschläge'));
      await tester.pumpAndSettle();
      expect(find.text('115,00 € pro Monat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('users cannot manage advance payments', (tester) async {
      await open(tester, role: 'USER');
      expect(find.text('Einstellungen'), findsNothing);
      expect(find.text('Abschläge verwalten'), findsNothing);
    });

    testWidgets('water meters offer no advance payments', (tester) async {
      await open(tester, type: 'WATER');
      await openMeters(tester);
      expect(find.text('Tarife verwalten'), findsOneWidget);
      expect(find.text('Abschläge verwalten'), findsNothing);
      expect(find.text('Abschläge'), findsNothing);
    });

    testWidgets('error codes are translated', (tester) async {
      await tester.pumpWidget(app(const SizedBox()));
      final l = lookupAppLocalizations(const Locale('de'));
      expect(
        errorText(l, 'ADVANCE_PAYMENT_DUPLICATE'),
        l.advancePaymentDuplicate,
      );
      expect(
        advancePaymentError(l, 'ADVANCE_PAYMENTS_UNSUPPORTED'),
        l.advancePaymentsUnsupported,
      );
    });
  });
}
