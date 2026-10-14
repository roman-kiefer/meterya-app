import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meterya_app/api_service.dart';
import 'package:meterya_app/app_theme.dart';
import 'package:meterya_app/audit_view.dart';
import 'package:meterya_app/audit_view_model.dart';
import 'package:meterya_app/billing_year_picker.dart';
import 'package:meterya_app/l10n/app_localizations.dart';
import 'package:meterya_app/models.dart';
import 'package:meterya_app/overview_frame.dart';
import 'package:meterya_app/repository.dart';
import 'package:meterya_app/settings_view.dart';
import 'package:meterya_app/view_model.dart';

Map<String, dynamic> entry(String id, {String type = 'ReadingRecorded'}) => {
  'id': id,
  'occurred_at': '2026-10-12T10:00:00Z',
  'event_type': type,
  'action': type,
  'workspace_id': 'ws',
  'workspace_name': 'Home',
  'actor': {'id': 'u', 'kind': 'user', 'name': 'mod@example.test'},
  'object': {'id': 'p', 'kind': 'point', 'name': 'Hauszähler'},
  'details': [
    {'field': 'date', 'value': '2026-10-01', 'format': 'date'},
    {'field': 'value', 'value': '123.000000', 'format': 'decimal'},
  ],
};
Map<String, dynamic> page(
  List<Map<String, dynamic>> entries, {
  String? cursor,
}) => {
  'entries': entries,
  'event_types': ['ReadingRecorded', 'ReadingCorrected'],
  'next_cursor': ?cursor,
};
Widget app(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: meteryaTheme(brightness: brightness),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
ViewModel modelFor(http.Client client, {String role = 'ADMIN'}) =>
    ViewModel(Repository(ApiService(client, Uri.parse('http://localhost'))))
      ..signedIn = true
      ..workspace = Workspace('ws', 'Home', role)
      ..workspaces = [Workspace('ws', 'Home', role)];

void main() {
  testWidgets(
    'settings close their contents when switching to a guest workspace',
    (tester) async {
      final client = MockClient((_) async => http.Response('[]', 200));
      addTearDown(client.close);
      final model = modelFor(client, role: 'MODERATOR');
      const guest = Workspace('ws2', 'Other', 'GUEST');
      model.workspaces = [model.workspace!, guest];
      await tester.pumpWidget(app(SettingsView(model: model)));
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsOneWidget);
      await model.select(guest);
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsNothing);
      expect(
        find.text(
          'Die Einstellungen sind nur für Admins und Moderatoren verfügbar.',
        ),
        findsOneWidget,
      );
      expect(find.text('Workspace anlegen'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'invitation types are distinct and details explain missing references',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final invitation = entry('invite', type: 'InvitationDeleted')
        ..['object'] = {
          'id': 'invite',
          'kind': 'invitation',
          'name': 'invite@example.test',
        }
        ..['details'] = [
          {
            'field': 'context',
            'value': 'InvitationDeleted',
            'format': 'explanation',
          },
        ];
      final missing = entry('missing', type: 'UnrecognizedA')
        ..['action'] = 'UnknownEvent'
        ..['object'] = {'id': 'legacy', 'kind': 'event', 'status': 'UNRESOLVED'}
        ..['details'] = [
          {
            'field': 'object_status',
            'value': 'UNRESOLVED',
            'format': 'explanation',
          },
        ];
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'entries': [invitation, missing],
            'event_types': [
              'MemberInvited',
              'InvitationRetried',
              'InvitationRevoked',
              'InvitationDeleted',
              'InvitationAccepted',
              'UnrecognizedA',
              'UnrecognizedB',
            ],
          }),
          200,
        ),
      );
      addTearDown(client.close);
      await tester.pumpWidget(app(AuditView(model: modelFor(client))));
      await tester.pumpAndSettle();
      expect(find.text('invite@example.test'), findsOneWidget);
      expect(find.textContaining('nicht mehr verfügbar'), findsNothing);
      await tester.tap(find.text('Alle Vorgänge'));
      await tester.pumpAndSettle();
      for (final label in [
        'Einladung erstellt',
        'Einladung erneut angefordert',
        'Einladung widerrufen',
        'Einladung angenommen',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Weiterer Vorgang'), findsNothing);
      expect(find.text('Sonstiger Vorgang (UnrecognizedB)'), findsOneWidget);
      await tester.tap(find.text('Einladung gelöscht').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Details anzeigen').first);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('die Aktion löscht kein Benutzerkonto'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Details anzeigen').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Das allein bedeutet nicht'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [360.0, 1280.0]) {
    testWidgets('audit table filters and expands at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <Uri>[];
      final client = MockClient((r) async {
        requests.add(r.url);
        if (r.url.queryParameters['cursor'] != null) {
          return http.Response(jsonEncode(page([entry('second')])), 200);
        }
        final type = r.url.queryParameters['event_type'];
        return http.Response(
          jsonEncode(
            page([
              entry('first', type: type ?? 'ReadingRecorded'),
            ], cursor: type == null ? 'cursor' : null),
          ),
          200,
        );
      });
      addTearDown(client.close);
      final model = modelFor(client);
      await tester.pumpWidget(
        app(
          AuditView(model: model),
          brightness: width == 360 ? Brightness.dark : Brightness.light,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BillingYearPicker), findsNothing);
      expect(find.text('Hauszähler'), findsOneWidget);
      if (width == 360) {
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(-900, 0),
        );
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Details anzeigen'));
      await tester.pumpAndSettle();
      expect(find.text('Zählerstand: 123'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Weitere laden'));
      await tester.pumpAndSettle();
      expect(find.text('Hauszähler'), findsNWidgets(2));
      expect(requests.last.queryParameters['cursor'], 'cursor');
      await tester.tap(find.text('Alle Vorgänge'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ablesung korrigiert').last);
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['event_type'], 'ReadingCorrected');
      expect(requests.last.queryParameters.containsKey('cursor'), isFalse);
      expect(find.text('Hauszähler'), findsOneWidget);
      expect(find.text('Zählerstand: 123'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('admin can choose all workspaces and retry failures', (
    tester,
  ) async {
    var failed = true;
    final requests = <Uri>[];
    final client = MockClient((r) async {
      requests.add(r.url);
      return failed
          ? http.Response('{"code":"INTERNAL_ERROR"}', 500)
          : http.Response(jsonEncode(page([entry('one')])), 200);
    });
    addTearDown(client.close);
    await tester.pumpWidget(app(AuditView(model: modelFor(client))));
    await tester.pumpAndSettle();
    failed = false;
    await tester.tap(find.text('Erneut versuchen'));
    await tester.pumpAndSettle();
    expect(find.text('Hauszähler'), findsOneWidget);
    await tester.tap(
      find.byWidgetPredicate((w) => w is DropdownButtonFormField<bool>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alle Workspaces').last);
    await tester.pumpAndSettle();
    expect(requests.last.path, '/api/v1/audit');
    expect(find.text('Workspace'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final role in ['ADMIN', 'MODERATOR', 'USER', 'GUEST']) {
    testWidgets('audit navigation without meters for $role', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = MockClient(
        (_) async => http.Response(jsonEncode(page([])), 200),
      );
      addTearDown(client.close);
      final model = modelFor(client, role: role);
      await tester.pumpWidget(
        app(
          WorkspaceScaffold(
            appBar: WorkspaceAppBar(model: model, title: const Text('Start')),
            body: AppNavigationFrame(model: model, child: const Text('Start')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final nav = find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Protokollierung'),
      );
      if (role == 'ADMIN' || role == 'MODERATOR') {
        expect(
          find.descendant(
            of: find.byType(NavigationRail),
            matching: find.text('Einstellungen'),
          ),
          findsOneWidget,
        );
        expect(nav, findsOneWidget);
        await tester.tap(nav);
        await tester.pumpAndSettle();
        expect(find.byType(AuditView), findsOneWidget);
        expect(find.text('Noch keine Vorgänge vorhanden.'), findsOneWidget);
        if (role == 'MODERATOR') {
          expect(
            find.byWidgetPredicate((w) => w is DropdownButtonFormField<bool>),
            findsNothing,
          );
        }
      } else {
        expect(nav, findsNothing);
        expect(find.text('Einstellungen'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
  test('filter and workspace changes discard late responses', () async {
    final pending = <Completer<http.Response>>[];
    final requests = <Uri>[];
    final client = MockClient((r) {
      requests.add(r.url);
      final c = Completer<http.Response>();
      pending.add(c);
      return c.future;
    });
    addTearDown(client.close);
    final audit = AuditViewModel(
      Repository(ApiService(client, Uri.parse('http://localhost'))),
    );
    addTearDown(audit.dispose);
    final old = audit.configure('ws', true);
    await Future<void>.delayed(Duration.zero);
    final fresh = audit.filter('ReadingCorrected');
    await Future<void>.delayed(Duration.zero);
    pending[1].complete(http.Response(jsonEncode(page([entry('fresh')])), 200));
    await fresh;
    pending[0].complete(http.Response('{"code":"INTERNAL_ERROR"}', 500));
    await old;
    expect(audit.entries.single.id, 'fresh');
    expect(audit.error, isNull);
    final workspace = audit.configure('ws2', true);
    expect(audit.entries, isEmpty);
    expect(audit.eventType, '');
    await Future<void>.delayed(Duration.zero);
    expect(requests.last.path, '/api/v1/workspaces/ws2/audit');
    pending[2].complete(http.Response(jsonEncode(page([])), 200));
    await workspace;
    expect(audit.entries, isEmpty);
  });
}
