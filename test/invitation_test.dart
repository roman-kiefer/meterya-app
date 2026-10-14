import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meterya_app/api_service.dart';
import 'package:meterya_app/invitation_view.dart';
import 'package:meterya_app/l10n/app_localizations.dart';
import 'package:meterya_app/repository.dart';

void main() {
  testWidgets('failed invitation stays visible and can be revoked', (
    tester,
  ) async {
    var status = 'FAILED';
    var version = 1;
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        expect(
          request.url.path,
          '/api/v1/workspaces/ws/invitations/invite/revoke',
        );
        expect(jsonDecode(request.body), {'expected_version': 1});
        expect(request.headers['X-CSRF-Token'], 'csrf');
        status = 'REVOKED';
        version++;
        return http.Response('{}', 200);
      }
      return http.Response(
        jsonEncode([
          {
            'id': 'invite',
            'email': 'user@example.test',
            'role': 'USER',
            'status': status,
            'version': version,
            'expires_at': DateTime.now()
                .add(const Duration(days: 7))
                .toUtc()
                .toIso8601String(),
          },
        ]),
        200,
      );
    });
    final service = ApiService(client, Uri.parse('http://localhost:8080'))
      ..csrf = 'csrf';
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: InvitationDialog(
            repository: Repository(service),
            workspace: 'ws',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Versand fehlgeschlagen'), findsOneWidget);
    await tester.tap(find.text('Widerrufen'));
    await tester.pumpAndSettle();
    expect(status, 'REVOKED');
    expect(find.text('Erneut senden'), findsNothing);
    expect(find.textContaining('User · Widerrufen'), findsOneWidget);
    client.close();
  });
}
