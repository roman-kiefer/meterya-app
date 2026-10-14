import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meterya_app/api_service.dart';
import 'package:meterya_app/main.dart';
import 'dart:convert';
import 'package:meterya_app/repository.dart';
import 'package:meterya_app/view_model.dart';

void main() {
  test(
    'invitation is accepted after session authentication and access is refreshed',
    () async {
      final paths = <String>[];
      var accepted = false;
      final client = MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path == '/api/v1/me') {
          return http.Response(
            jsonEncode({
              'csrf_token': 'csrf',
              'workspaces': accepted
                  ? [
                      {'id': 'ws1', 'name': 'Haus', 'role': 'ADMIN'},
                      {'id': 'ws2', 'name': 'Garten', 'role': 'ADMIN'},
                    ]
                  : [],
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/invitations/accept') {
          expect(request.method, 'POST');
          expect(request.headers['X-CSRF-Token'], 'csrf');
          expect(jsonDecode(request.body), {'token': 'invite-token'});
          accepted = true;
          return http.Response('{}', 200);
        }
        return http.Response('[]', 200);
      });
      addTearDown(client.close);
      final model = ViewModel(
        Repository(ApiService(client, Uri.parse('http://localhost'))),
      );
      final destinations = <String>[];
      await initializeSession(
        model,
        'invite-token',
        redirect: destinations.add,
      );
      expect(paths.take(3), [
        '/api/v1/me',
        '/api/v1/invitations/accept',
        '/api/v1/me',
      ]);
      expect(destinations, ['/']);
      expect(model.signedIn, isTrue);
      expect(model.error, isNull);
      expect(model.workspaces.length, 2);
      expect(
        model.workspaces.every((workspace) => workspace.isSystemAdmin),
        isTrue,
      );
      expect(model.workspace?.id, 'ws1');
    },
  );

  for (final code in [
    'AUTHENTICATION_REQUIRED',
    'MFA_REQUIRED',
    'INVITATION_UNAVAILABLE',
  ]) {
    test(
      'automatic acceptance stops on $code without granting access',
      () async {
        var attempts = 0;
        final client = MockClient((request) async {
          if (request.url.path == '/api/v1/me') {
            if (code == 'AUTHENTICATION_REQUIRED') {
              return http.Response(jsonEncode({'code': code}), 401);
            }
            return http.Response('{"csrf_token":"csrf","workspaces":[]}', 200);
          }
          if (request.url.path == '/api/v1/invitations/accept') {
            attempts++;
            return http.Response(jsonEncode({'code': code}), 403);
          }
          fail('Workspace data must not load before acceptance');
        });
        addTearDown(client.close);
        final model = ViewModel(
          Repository(ApiService(client, Uri.parse('http://localhost'))),
        );
        final destinations = <String>[];
        await initializeSession(
          model,
          'invite-token',
          redirect: destinations.add,
        );
        expect(model.error, code);
        if (code == 'MFA_REQUIRED') {
          final login = Uri.parse(destinations.single);
          expect(login.path, '/auth/login');
          expect(login.queryParameters['mfa'], '1');
          final returnTo = Uri.parse(login.queryParameters['return_to']!);
          expect(returnTo.path, '/invitations/accept');
          expect(returnTo.queryParameters['token'], 'invite-token');
        } else {
          expect(destinations, isEmpty);
        }
        expect(attempts, code == 'AUTHENTICATION_REQUIRED' ? 0 : 1);
        expect(model.workspace, isNull);
        expect(model.workspaces, isEmpty);
        if (code == 'AUTHENTICATION_REQUIRED') expect(model.signedIn, isFalse);
      },
    );
  }

  testWidgets('account without active access has no unsolicited MFA button', (
    tester,
  ) async {
    final model = ViewModel(
      Repository(
        ApiService(
          MockClient((_) async => http.Response('{}', 200)),
          Uri.parse('http://localhost'),
        ),
      ),
    )..signedIn = true;
    await tester.pumpWidget(MeteryaApp(model: model));
    expect(find.textContaining('noch kein aktiver Zugriff'), findsOneWidget);
    expect(find.text('Mit zweitem Faktor anmelden'), findsNothing);
  });
}
