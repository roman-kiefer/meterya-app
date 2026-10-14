import 'navigation_helpers.dart';
import 'package:meterya_app/settings_view.dart';
import 'package:meterya_app/overview_frame.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meterya_app/api_service.dart';
import 'package:meterya_app/main.dart';
import 'package:meterya_app/repository.dart';
import 'package:meterya_app/view_model.dart';

class SettingsFixture {
  String workspaceName = 'Haushalt', pointName = 'Haus';
  String serial = '123';
  int workspaceVersion = 1, pointVersion = 3;
  bool archived = false, conflict = false, deleted = false;
  bool expired = false;
  final String role;
  final requests = <http.Request>[];
  late final client = MockClient((r) async {
    requests.add(r);
    dynamic response;
    if (r.method == 'POST') {
      if (expired) {
        return http.Response(
          jsonEncode({'code': 'AUTHENTICATION_REQUIRED'}),
          401,
        );
      }
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      expect(r.headers['X-CSRF-Token'], 'csrf');
      expect(r.headers['Idempotency-Key'], isNotEmpty);
      if (conflict) {
        return http.Response(
          jsonEncode({'code': 'AGGREGATE_VERSION_CONFLICT'}),
          409,
        );
      }
      if (r.url.path == '/api/v1/workspaces/ws/rename') {
        expect(body['expected_version'], workspaceVersion);
        workspaceName = body['name'] as String;
        workspaceVersion++;
      } else {
        expect(body['expected_version'], pointVersion);
        if (r.url.path.endsWith('/details')) {
          pointName = body['name'] as String;
          serial = body['serial'] as String;
        }
        if (r.url.path.endsWith('/archive')) archived = true;
        if (r.url.path.endsWith('/restore')) archived = false;
        if (r.url.path.endsWith('/purge')) {
          expect(body['confirm_point_id'], 'point');
          deleted = true;
        }
        pointVersion++;
      }
      response = {};
    } else if (r.url.path == '/api/v1/me') {
      response = {
        'csrf_token': 'csrf',
        'workspaces': [
          {
            'id': 'ws',
            'name': workspaceName,
            'version': workspaceVersion,
            'role': role,
          },
        ],
      };
    } else if (r.url.path.endsWith('/members')) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      response = {'version': 1, 'members': []};
    } else if (r.url.path.endsWith('/invitations') ||
        r.url.path.endsWith('/power-to-heat') ||
        r.url.path.endsWith('/transitions')) {
      response = [];
    } else {
      expect(r.url.queryParameters['include_archived'], 'true');
      response = deleted
          ? []
          : [
              {
                'id': 'point',
                'name': pointName,
                'version': pointVersion,
                'archived': archived,
                'meter': {
                  'serial': serial,
                  'registers': [
                    {'id': 'reg', 'direction': 'IMPORT', 'unit': 'kWh'},
                  ],
                },
                'readings': [
                  {
                    'id': 'reading',
                    'date': '2026-01-01',
                    'register_id': 'reg',
                    'value': '123.000000',
                  },
                ],
              },
            ];
    }
    return http.Response(jsonEncode(response), 200);
  });
  late final model = ViewModel(
    Repository(ApiService(client, Uri.parse('http://localhost:8080'))),
  );
  SettingsFixture({this.role = 'ADMIN'});
  Future<void> open(WidgetTester tester) async {
    await model.initialize();
    await tester.pumpWidget(MeteryaApp(model: model));
    await tester.pumpAndSettle();
    if (find.byTooltip('Menü öffnen').evaluate().isNotEmpty) {
      await tester.tap(find.byTooltip('Menü öffnen'));
      await tester.pumpAndSettle();
    }
    if (model.workspace?.isAdmin == true) {
      await tester.tap(find.text('Einstellungen'));
      await tester.pumpAndSettle();
    }
  }

  void dispose() {
    model.dispose();
    client.close();
  }
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'settings separate tasks and open tariff editor on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = SettingsFixture();
      await fixture.open(tester);
      expect(find.text('Workspace umbenennen'), findsOneWidget);
      expect(find.byIcon(Icons.backup_outlined), findsNothing);
      fixture.model.repository.isOperator = true;
      fixture.model.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.backup_outlined), findsOneWidget);
      expect(find.text('Zähler bearbeiten'), findsNothing);
      expect(find.text('Mitglieder verwalten'), findsNothing);
      await tapVisible(tester, find.text('Zähler & Tarife'));
      expect(find.text('Workspace umbenennen'), findsNothing);
      expect(find.text('Mitglieder verwalten'), findsNothing);
      await tapVisible(tester, find.text('Tarife verwalten'));
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Mitglieder'));
      expect(find.text('Mitglieder verwalten'), findsNothing);
      expect(find.text('Nutzer & Einladungen'), findsOneWidget);
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('Mitglieder einladen'), findsOneWidget);
      expect(find.text('Zähler bearbeiten'), findsNothing);
      expect(fixture.requests.where((r) => r.method == 'POST'), isEmpty);
      expect(tester.takeException(), isNull);
      fixture.dispose();
    },
  );

  testWidgets('archived meters have readable details and no tariff editing', (
    tester,
  ) async {
    final fixture = SettingsFixture()..archived = true;
    await fixture.open(tester);
    await tapVisible(tester, find.text('Zähler & Tarife'));
    expect(find.text('Tarife verwalten'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Details'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tapVisible(tester, find.text('Details'));
    await selectSection(
      tester,
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
      'Ablesungen',
    );
    await tester.pumpAndSettle();
    expect(find.text('123 kWh'), findsOneWidget);
    await tester.tap(find.byTooltip('Menü öffnen'));
    await tester.pumpAndSettle();
    final record = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Ablesung erfassen'),
    );
    expect(record.onPressed, isNull);
    expect(find.text('Tarife verwalten'), findsNothing);
    expect(fixture.requests.where((r) => r.method == 'POST'), isEmpty);
    fixture.dispose();
  });

  testWidgets(
    'expired session during workspace rename offers login and hides administrative actions',
    (tester) async {
      final fixture = SettingsFixture();
      await fixture.open(tester);
      await tapVisible(tester, find.text('Workspace umbenennen'));
      await tester.enterText(find.byType(TextFormField).first, 'Wohnung');
      fixture.expired = true;
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(fixture.model.signedIn, isFalse);
      expect(fixture.model.repository.api.csrf, isNull);
      expect(fixture.model.workspace!.name, 'Haushalt');
      expect(
        find.text(
          'Deine Anmeldung ist abgelaufen. Bitte erneut anmelden und die Änderung danach wiederholen.',
        ),
        findsWidgets,
      );
      expect(find.widgetWithText(FilledButton, 'Anmelden'), findsWidgets);
      expect(find.text('Zähler bearbeiten'), findsNothing);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(find.text('Workspace umbenennen'), findsNothing);
      fixture.expired = false;
      await fixture.model.initialize();
      await tester.pumpAndSettle();
      expect(find.text('Workspace umbenennen'), findsOneWidget);
      expect(fixture.model.repository.api.csrf, 'csrf');
      fixture.dispose();
    },
  );

  testWidgets(
    'serial correction preserves readings and requires current version',
    (tester) async {
      final fixture = SettingsFixture();
      await fixture.open(tester);
      await tapVisible(tester, find.text('Zähler & Tarife'));
      await tapVisible(tester, find.text('Zähler bearbeiten'));
      expect(find.byType(TextFormField), findsNWidgets(2));
      await tester.enterText(find.byType(TextFormField).last, 'RICHTIG-456');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(fixture.model.points.single.serial, 'RICHTIG-456');
      expect(fixture.model.points.single.name, 'Haus');
      expect(fixture.model.points.single.readings.single.id, 'reading');
      expect(
        fixture.requests.where((r) => r.url.path.endsWith('/details')),
        hasLength(1),
      );
      fixture.dispose();
    },
  );

  testWidgets(
    'permanent deletion requires typed confirmation and cancellation sends no request',
    (tester) async {
      final fixture = SettingsFixture();
      await fixture.open(tester);
      await tapVisible(tester, find.text('Zähler & Tarife'));
      await tapVisible(tester, find.text('Endgültig löschen'));
      final button = find.widgetWithText(FilledButton, 'Endgültig löschen');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'Anderer Zähler');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(fixture.requests.where((r) => r.method == 'POST'), isEmpty);
      await tapVisible(tester, find.text('Zähler & Tarife'));
      await tapVisible(tester, find.text('Endgültig löschen'));
      await tester.enterText(find.byType(TextField), 'Haus');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(fixture.model.points, isEmpty);
      expect(fixture.model.archivedPoints, isEmpty);
      expect(
        fixture.requests.where((r) => r.url.path.endsWith('/purge')),
        hasLength(1),
      );
      fixture.dispose();
    },
  );

  testWidgets(
    'settings rename workspace and meter; archive and restore preserve readings',
    (tester) async {
      final fixture = SettingsFixture();
      await fixture.open(tester);
      expect(find.text('Workspaces verwalten'), findsOneWidget);
      await tapVisible(tester, find.text('Workspace umbenennen'));
      await tester.enterText(find.byType(TextFormField).first, 'Wohnung');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(fixture.model.workspace!.name, 'Wohnung');
      expect(fixture.model.workspace!.version, 2);
      await tapVisible(tester, find.text('Zähler & Tarife'));
      await tapVisible(tester, find.text('Zähler bearbeiten'));
      await tester.enterText(find.byType(TextFormField).first, 'Obergeschoss');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(fixture.model.activePoints.single.name, 'Obergeschoss');
      await tapVisible(tester, find.text('Zähler archivieren'));
      expect(find.text('Zähler archivieren?'), findsOneWidget);
      expect(
        find.textContaining(
          'Ablesungen, Tarife und Abrechnungen bleiben erhalten.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(
        fixture.requests.where((r) => r.url.path.endsWith('/archive')),
        isEmpty,
      );
      await tapVisible(tester, find.text('Zähler archivieren'));
      await tester.tap(find.widgetWithText(FilledButton, 'Zähler archivieren'));
      await tester.pumpAndSettle();
      expect(fixture.model.activePoints, isEmpty);
      expect(
        fixture.model.archivedPoints.single.readings.single.value,
        '123.000000',
      );
      await tapVisible(tester, find.text('Zähler wiederherstellen'));
      await tester.tap(
        find.widgetWithText(FilledButton, 'Zähler wiederherstellen'),
      );
      await tester.pumpAndSettle();
      expect(fixture.model.archivedPoints, isEmpty);
      expect(fixture.model.activePoints.single.readings.single.id, 'reading');
      if (find.byTooltip('Menü öffnen').evaluate().isNotEmpty) {
        await tester.tap(find.byTooltip('Menü öffnen'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Übersicht'));
      } else {
        await tester.tap(find.text('Übersicht'));
      }
      await tester.pumpAndSettle();
      expect(find.text('Obergeschoss'), findsOneWidget);
      expect(fixture.requests.where((r) => r.method == 'POST'), hasLength(4));
      fixture.dispose();
    },
  );

  testWidgets('USER cannot see or open settings', (tester) async {
    final fixture = SettingsFixture(role: 'USER');
    await fixture.open(tester);
    expect(find.text('Einstellungen'), findsNothing);
    Navigator.of(tester.element(find.byType(WorkspaceScaffold))).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsView(model: fixture.model),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Die Einstellungen sind nur für Admins und Moderatoren verfügbar.',
      ),
      findsOneWidget,
    );
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('Zähler bearbeiten'), findsNothing);
    expect(find.text('Zähler archivieren'), findsNothing);
    expect(find.text('Endgültig löschen'), findsNothing);
    expect(find.text('Workspace umbenennen'), findsNothing);
    expect(find.text('Zähler anlegen'), findsNothing);
    expect(find.text('Workspaces verwalten'), findsNothing);
    fixture.dispose();
  });

  testWidgets(
    'conflict leaves form and history intact; refresh loads latest versions',
    (tester) async {
      final fixture = SettingsFixture()..conflict = true;
      await fixture.open(tester);
      await tapVisible(tester, find.text('Zähler & Tarife'));
      await tapVisible(tester, find.text('Zähler bearbeiten'));
      await tester.enterText(find.byType(TextFormField).first, 'Entwurf');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(fixture.model.points.single.name, 'Haus');
      expect(fixture.model.points.single.readings, hasLength(1));
      expect(fixture.model.error, 'AGGREGATE_VERSION_CONFLICT');
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      fixture.conflict = false;
      fixture.pointVersion = 7;
      fixture.workspaceName = 'Aktueller Haushalt';
      await tester.tap(find.byTooltip('Aktualisieren').last);
      await tester.pumpAndSettle();
      expect(fixture.model.workspace!.name, 'Aktueller Haushalt');
      expect(fixture.model.points.single.version, 7);
      await tapVisible(tester, find.text('Zähler & Tarife'));
      await tapVisible(tester, find.text('Zähler bearbeiten'));
      await tester.enterText(find.byType(TextFormField).first, 'Neu');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(fixture.model.points.single.version, 8);
      expect(fixture.model.points.single.name, 'Neu');
      fixture.dispose();
    },
  );
}
