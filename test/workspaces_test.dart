import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meterya_app/api_service.dart';
import 'package:meterya_app/main.dart';
import 'package:meterya_app/members_grid.dart';
import 'package:meterya_app/repository.dart';
import 'package:meterya_app/view_model.dart';

class Fixture {
  final String role;
  int version = 1;
  bool conflict = false;
  final workspaces = <Map<String, dynamic>>[];
  final members = <Map<String, dynamic>>[
    {'subject': 'admin', 'email': 'admin@example.test', 'role': 'ADMIN'},
    {'subject': 'user', 'email': 'user@example.test', 'role': 'USER'},
  ];
  final invites = <Map<String, dynamic>>[];
  final posts = <http.Request>[];
  late final client = MockClient((r) async {
    dynamic result;
    if (r.method == 'POST') {
      posts.add(r);
      expect(r.headers['X-CSRF-Token'], 'csrf');
      expect(r.headers['Idempotency-Key'], isNotEmpty);
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      if (conflict) {
        return http.Response(
          jsonEncode({'code': 'AGGREGATE_VERSION_CONFLICT'}),
          409,
        );
      }
      if (r.url.path == '/api/v1/workspaces') {
        result = {
          'id': 'new',
          'name': body['name'],
          'role': 'ADMIN',
          'version': 1,
        };
        workspaces.add(result as Map<String, dynamic>);
      } else if (r.url.path.endsWith('/invitations/revoked/delete')) {
        expect(body['expected_version'], 1);
        invites.clear();
        result = {};
      } else {
        expect(r.url.path, startsWith('/api/v1/workspaces/ws/members/'));
        expect(body['expected_version'], version);
        if (r.url.path.endsWith('/remove')) {
          members.removeWhere((m) => m['subject'] == body['subject']);
        } else if (r.url.path.endsWith('/activity')) {
          members.firstWhere((m) => m['subject'] == body['subject'])['active'] =
              body['active'];
        } else {
          members.firstWhere((m) => m['subject'] == body['subject'])['role'] =
              body['role'];
        }
        version++;
        workspaces.first['version'] = version;
        result = {'updated': true};
      }
    } else if (r.url.path == '/api/v1/me') {
      result = {'csrf_token': 'csrf', 'workspaces': workspaces};
    } else if (r.url.path.endsWith('/invitations')) {
      result = invites;
    } else if (r.url.path.endsWith('/members')) {
      result = {'version': version, 'members': members};
    } else {
      result = [];
    }
    return http.Response(jsonEncode(result), 200);
  });
  late final model = ViewModel(
    Repository(ApiService(client, Uri.parse('http://localhost:8080'))),
  );
  Fixture({this.role = 'ADMIN'}) {
    workspaces.add({
      'id': 'ws',
      'name': 'Haushalt',
      'role': role,
      'version': 1,
    });
  }
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'moderator can delete revoked invites and toggle member activity',
    (tester) async {
      final f = Fixture(role: 'MODERATOR');
      f.invites.add({
        'id': 'revoked',
        'email': 'invited@example.test',
        'role': 'ADMIN',
        'status': 'REVOKED',
        'version': 1,
        'expires_at': DateTime.now()
            .add(const Duration(days: 2))
            .toIso8601String(),
      });
      await f.open(tester);
      await tap(tester, find.text('Mitglieder'));
      Finder actions(String text) => find.descendant(
        of: find.ancestor(
          of: find.text(text),
          matching: find.byType(DataTable),
        ),
        matching: find.byType(PopupMenuButton<String>),
      );
      await tap(tester, actions('invited@example.test').last);
      await tap(
        tester,
        find.widgetWithText(PopupMenuItem<String>, 'Einladung löschen'),
      );
      expect(f.posts, isEmpty);
      await tap(tester, find.widgetWithText(FilledButton, 'Einladung löschen'));
      expect(find.text('invited@example.test'), findsNothing);
      await tap(tester, actions('user@example.test').at(1));
      await tap(
        tester,
        find.widgetWithText(PopupMenuItem<String>, 'Inaktiv schalten'),
      );
      expect(f.members.last['active'], isNull);
      await tap(tester, find.widgetWithText(FilledButton, 'Inaktiv schalten'));
      expect(find.text('Inaktiv'), findsOneWidget);
      expect(f.members.last['active'], isFalse);
      await tap(tester, actions('user@example.test').at(1));
      await tap(
        tester,
        find.widgetWithText(PopupMenuItem<String>, 'Aktivieren'),
      );
      await tap(tester, find.widgetWithText(FilledButton, 'Aktivieren'));
      expect(f.members.last['active'], isTrue);
      expect(find.text('Inaktiv'), findsNothing);
      expect(f.posts.length, 3);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      f.dispose();
    },
  );
  testWidgets('create a workspace selects it and retains the first workspace', (
    tester,
  ) async {
    final f = Fixture();
    await f.open(tester);
    await tap(tester, find.text('Workspace anlegen'));
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(f.posts, isEmpty);
    await tester.enterText(find.byType(TextFormField), 'Wohnung');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(f.model.workspaces, hasLength(2));
    expect(f.model.workspace!.name, 'Wohnung');
    expect(f.posts.single.url.path, '/api/v1/workspaces');
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
    f.dispose();
  });
  testWidgets(
    'member roles and removal require confirmation and refresh the list',
    (tester) async {
      final f = Fixture();
      await f.open(tester);
      await tap(tester, find.text('Mitglieder'));
      expect(
        tester
            .widget<PopupMenuButton<String>>(
              find
                  .descendant(
                    of: find.byType(MembersGrid),
                    matching: find.byType(PopupMenuButton<String>),
                  )
                  .at(0),
            )
            .enabled,
        isFalse,
      );
      await tap(
        tester,
        find
            .descendant(
              of: find.byType(MembersGrid),
              matching: find.byType(PopupMenuButton<String>),
            )
            .at(1),
      );
      await tap(tester, find.widgetWithText(PopupMenuItem<String>, 'Admin'));
      expect(f.posts, isEmpty);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(f.posts, isEmpty);
      await tap(
        tester,
        find
            .descendant(
              of: find.byType(MembersGrid),
              matching: find.byType(PopupMenuButton<String>),
            )
            .at(1),
      );
      await tap(tester, find.widgetWithText(PopupMenuItem<String>, 'Admin'));
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(f.members.last['role'], 'ADMIN');
      await tap(
        tester,
        find
            .descendant(
              of: find.byType(MembersGrid),
              matching: find.byType(PopupMenuButton<String>),
            )
            .at(1),
      );
      await tap(
        tester,
        find.widgetWithText(PopupMenuItem<String>, 'Zugriff entziehen'),
      );
      expect(
        find.textContaining('Zähler und Ablesungen bleiben erhalten'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Zugriff entziehen'));
      await tester.pumpAndSettle();
      expect(find.text('user@example.test'), findsNothing);
      expect(f.posts.length, 2);
      expect(jsonDecode(f.posts.last.body)['expected_version'], 2);
      await tester.pumpWidget(const SizedBox());
      f.dispose();
    },
  );
  testWidgets('stale member changes remain visible and can be refreshed', (
    tester,
  ) async {
    final f = Fixture();
    await f.open(tester);
    await tap(tester, find.text('Mitglieder'));
    f.conflict = true;
    await tap(
      tester,
      find
          .descendant(
            of: find.byType(MembersGrid),
            matching: find.byType(PopupMenuButton<String>),
          )
          .at(1),
    );
    await tap(tester, find.widgetWithText(PopupMenuItem<String>, 'Admin'));
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(f.members.last['role'], 'USER');
    expect(f.model.error, 'AGGREGATE_VERSION_CONFLICT');
    expect(find.text('user@example.test'), findsOneWidget);
    f.conflict = false;
    await tester.tap(find.text('Aktualisieren'));
    await tester.pumpAndSettle();
    expect(f.model.error, isNull);
    await tester.pumpWidget(const SizedBox());
    f.dispose();
  });
  testWidgets('users have no workspace creation or membership controls', (
    tester,
  ) async {
    final f = Fixture(role: 'USER');
    await f.open(tester);
    expect(find.text('Workspace anlegen'), findsNothing);
    expect(find.text('Einstellungen'), findsNothing);
    expect(find.text('Mitglieder'), findsNothing);
    expect(find.text('Mitglieder verwalten'), findsNothing);
    expect(find.text('Mitglieder einladen'), findsNothing);
    expect(f.posts, isEmpty);
    await tester.pumpWidget(const SizedBox());
    f.dispose();
  });
}
