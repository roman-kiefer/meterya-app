import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meterya_app/api_service.dart';
import 'package:meterya_app/app_theme.dart';
import 'package:meterya_app/l10n/app_localizations.dart';
import 'package:meterya_app/models.dart';
import 'package:meterya_app/monthly_overview_view.dart';
import 'package:meterya_app/overview_dashboard.dart';
import 'package:meterya_app/report.dart';
import 'package:meterya_app/report_delivery.dart';
import 'package:meterya_app/repository.dart';
import 'package:meterya_app/view_model.dart';
import 'package:meterya_app/virtual_point_dialog.dart';
import 'package:meterya_app/virtual_readings_view.dart';

Map<String, dynamic> virtualFixture({bool heat = false}) {
  final register = heat ? 'virtual-TOTAL' : 'virtual-IMPORT';
  Map<String, dynamic> summary() => {
    'year': 2026,
    'point_version': 1,
    'calculation_version': 3,
    'complete': false,
    'estimated': false,
    'warnings': ['MEASUREMENT_GAP'],
    'base_cents': '1000',
    'net_cents': '1359',
    'positions': [
      {
        'register_id': register,
        'direction': heat ? 'CONSUMPTION' : 'IMPORT',
        'unit': 'kWh',
        'quantity': '20.000000',
        'covered_from': '2026-01-01',
        'covered_until': '2026-02-01',
        'cents': '359',
        'complete': false,
        'estimated': false,
      },
      if (heat)
        for (final direction in ['GRID', 'PV'])
          {
            'register_id': 'virtual-$direction',
            'direction': direction == 'GRID' ? 'IMPORT' : 'SELF',
            'unit': 'kWh',
            'quantity': '10.000000',
            'covered_from': '2026-01-01',
            'covered_until': '2026-02-01',
            'complete': false,
            'estimated': false,
          },
    ],
    'overview': [
      {'register_id': register, 'total_cents': '1359', 'changing_rate': false},
    ],
  };
  final annual = summary()
    ..['months'] = [
      {...summary(), 'month': 1},
    ];
  return {
    'id': 'virtual',
    'name': 'Logischer Hausanschluss',
    'kind': 'VIRTUAL',
    'version': 1,
    'meter': {
      'serial': '',
      'registers': [
        {
          'id': register,
          'direction': heat ? 'CONSUMPTION' : 'IMPORT',
          'unit': 'kWh',
        },
        if (heat)
          for (final direction in ['GRID', 'PV'])
            {
              'id': 'virtual-$direction',
              'direction': direction == 'GRID' ? 'IMPORT' : 'SELF',
              'unit': 'kWh',
            },
      ],
    },
    'readings': [],
    'consumption': [],
    'annual': [annual],
    'monthly_billing': [],
    'virtual': {
      'definition': {
        'id': 'virtual',
        'workspace_id': 'ws',
        'name': 'Logischer Hausanschluss',
        'type': heat ? 'HEAT' : 'SEQUENCE',
        'root_point': 'old',
        'choices': {},
        'version': 1,
        'archived': false,
        'deleted': false,
      },
      'data_version': 'source-snapshot',
      'source_versions': {'old': 3, 'new': 2},
      'flags': [],
      'sources': [
        {
          'point_id': 'old',
          'name': 'Alt',
          'valid_from': '',
          'valid_until': '2026-06-01',
        },
        {
          'point_id': 'new',
          'name': 'Neu',
          'valid_from': '2026-06-01',
          'valid_until': '',
        },
      ],
      'periods': [
        {
          'register_id': register,
          'start_date': '2026-01-01',
          'end_date': '2026-02-01',
          'quantity': '20.000000',
          'unit': 'kWh',
          'source_ids': ['old', 'new'],
          'valid': true,
          if (heat) 'grid_quantity': '10.000000',
          if (heat) 'house_pv_quantity': '10.000000',
        },
        if (heat)
          for (final direction in ['GRID', 'PV'])
            {
              'register_id': 'virtual-$direction',
              'start_date': '2026-01-01',
              'end_date': '2026-02-01',
              'quantity': '10.000000',
              'unit': 'kWh',
              'source_ids': ['old', 'new'],
              'valid': true,
            },
      ],
    },
  };
}

Map<String, dynamic> physicalFixture(String id, String name) => {
  'id': id,
  'name': name,
  'version': 1,
  'meter': {'serial': id, 'registers': []},
  'readings': [],
};

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets(
      'virtual meters use API values and hide raw sources at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final client = MockClient((_) async => http.Response('[]', 200));
        addTearDown(client.close);
        final model = ViewModel(
          Repository(ApiService(client, Uri.parse('http://localhost'))),
        )..signedIn = true;
        model.workspace = const Workspace('ws', 'Home', 'ADMIN');
        model.points = [
          Point.fromJson(virtualFixture()),
          Point.fromJson(physicalFixture('old', 'Alt')),
          Point.fromJson(physicalFixture('new', 'Neu')),
          Point.fromJson(physicalFixture('water', 'Unabhängig')),
        ];
        model.selectBillingYear(2026);
        await tester.pumpWidget(
          MaterialApp(
            theme: meteryaTheme(
              brightness: width == 390 ? Brightness.dark : Brightness.light,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: OverviewDashboard(model: model),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Virtuell · berechnet'), findsWidgets);
        expect(find.text('Unabhängig'), findsOneWidget);
        expect(find.text('Alt'), findsNothing);
        expect(find.text('Neu'), findsNothing);
        await tester.tap(find.text('Physische Quellen'));
        await tester.pumpAndSettle();
        expect(find.text('Alt'), findsOneWidget);
        expect(find.text('Neu'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'virtual heat months have no counter or apparent total energy tariff',
    (tester) async {
      final point = Point.fromJson(virtualFixture(heat: true));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyOverviewView(
                point: point,
                summary: point.annual!.single,
                year: 2026,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Zählerstand'), findsNothing);
      expect(find.text('Arbeitspreis'), findsNothing);
      expect(find.textContaining('Netzkosten:'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final label in ['Bezug', 'Haus/PV']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.textContaining('Netzkosten:'), findsNothing);
        expect(find.text('Arbeitspreis'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'calculated periods explain sources and grid/PV with server yearly total',
    (tester) async {
      final point = Point.fromJson(virtualFixture(heat: true));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: VirtualReadingsView(point: point, year: 2026)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Berechnete Zeiträume'), findsOneWidget);
      expect(find.text('Alt, Neu'), findsOneWidget);
      expect(find.textContaining('Haus/PV: 10'), findsOneWidget);
      expect(find.text('Jahressumme'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Bezug'));
      await tester.pumpAndSettle();
      expect(find.text('Bezug: 10 kWh'), findsNWidgets(2));
      expect(find.textContaining('Haus/PV: 10'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'creating a branch virtual meter requires an explicit physical continuation',
    (tester) async {
      var created = false;
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          expect(request.url.path, '/api/v1/workspaces/ws/virtual-points');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['expected_version'], 0);
          expect(body['definition'], {
            'name': 'Haus',
            'type': 'SEQUENCE',
            'choices': {'old': 'new'},
            'archived': false,
            'root_point': 'old',
          });
          expect(request.headers['X-CSRF-Token'], 'csrf');
          expect(request.headers['Idempotency-Key'], isNotEmpty);
          created = true;
          return http.Response('{}', 200);
        }
        if (request.url.path == '/api/v1/me') {
          return http.Response(
            '{"csrf_token":"csrf","workspaces":[{"id":"ws","name":"Home","role":"ADMIN"}]}',
            200,
          );
        }
        if (request.url.path.endsWith('/virtual-points')) {
          return http.Response(
            jsonEncode({
              'definitions': [],
              'transitions': [
                {
                  'id': 'change',
                  'old_point': 'old',
                  'new_points': ['new', 'inside'],
                  'date': '2026-06-01',
                },
              ],
              'heat': [],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/points')) {
          return http.Response(
            jsonEncode([
              physicalFixture('old', 'Alt'),
              physicalFixture('new', 'Neu'),
              physicalFixture('inside', 'Innenzähler'),
              if (created) virtualFixture(),
            ]),
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
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    showVirtualPointDialog(context, model, root: 'old'),
                child: const Text('Öffnen'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Öffnen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Haus');
      await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
      await tester.pumpAndSettle();
      expect(created, isFalse);
      expect(
        find.textContaining('Wähle bei mehreren Nachfolgern'),
        findsOneWidget,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Neu').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
      await tester.pumpAndSettle();
      expect(created, isTrue);
      expect(find.byType(VirtualPointDialog), findsNothing);
      expect(model.activePhysicalPoints.length, 3);
      expect(model.points.where((p) => p.isVirtual).length, 1);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'virtual export includes source metadata and validates its data token',
    () async {
      final point = Point.fromJson(virtualFixture());
      final report = BillingReport(
        const Workspace('ws', 'Home', 'ADMIN'),
        point,
        point.annual!.single,
        DateTime.utc(2026),
      );
      expect(report.toJson()['kind'], 'VIRTUAL');
      expect(
        (report.toJson()['virtual'] as Map)['data_version'],
        'source-snapshot',
      );
      final client = MockClient((request) async {
        expect(jsonDecode(request.body)['data_version'], 'source-snapshot');
        return http.Response(
          jsonEncode({
            'download_url':
                '${request.url.path}/12345678-1234-1234-1234-123456789012',
          }),
          201,
        );
      });
      addTearDown(client.close);
      final delivery = ServerReportDelivery(
        ApiService(client, Uri.parse('http://localhost')),
        const Workspace('ws', 'Home', 'ADMIN'),
        point,
        point.annual!.single,
        download: (_, _) {},
      );
      await delivery.save(
        const ReportFile('report.json', 'application/json', '{}'),
      );
    },
  );
}
