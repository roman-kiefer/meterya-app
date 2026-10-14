import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meterya_app/api_service.dart';
import 'package:meterya_app/main.dart';
import 'package:meterya_app/repository.dart';
import 'package:meterya_app/view_model.dart';
import 'package:meterya_app/profile_view.dart';

void main() {
  for (final width in [360.0, 1280.0]) {
    testWidgets(
      'profile keeps draft on failure and saves only names at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var fail = true;
        var writes = 0;
        final client = MockClient((r) async {
          expect(r.url.path, '/api/v1/profile');
          if (r.method == 'POST') {
            writes++;
            expect(r.headers['X-CSRF-Token'], 'csrf');
            expect(jsonDecode(r.body), {
              'firstName': 'Anna',
              'lastName': 'Müller',
            });
            if (fail) return http.Response('{"code":"INTERNAL_ERROR"}', 500);
          }
          return http.Response(
            jsonEncode({
              'firstName': writes > 0 && !fail ? 'Anna' : 'Roman',
              'lastName': 'Müller',
              'email': 'verified@example.test',
              'emailVerified': true,
              'authenticationMethods': {
                'password': true,
                'otp': true,
                'passkey': false,
                'recovery': true,
              },
            }),
            200,
          );
        });
        final api = ApiService(client, Uri.parse('http://localhost'))
          ..csrf = 'csrf';
        final model = ViewModel(Repository(api))..signedIn = true;
        await tester.pumpWidget(MeteryaApp(model: model));
        await tester.tap(find.byTooltip('Profil'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Profil bearbeiten'));
        await tester.pumpAndSettle();
        expect(find.byType(ProfileView), findsOneWidget);
        expect(find.text('verified@example.test'), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Vorname'),
          'Anna',
        );
        await tester.tap(find.text('Speichern'));
        await tester.pumpAndSettle();
        expect(find.text('Anna'), findsOneWidget);
        fail = false;
        await tester.tap(find.text('Speichern'));
        await tester.pumpAndSettle();
        expect(find.text('Profil gespeichert.'), findsOneWidget);
        expect(writes, 2);
        await tester.ensureVisible(find.text('Passkey / Sicherheitsschlüssel'));
        await tester.pumpAndSettle();
        expect(find.text('Eingerichtet'), findsNWidgets(3));
        expect(find.text('Nicht eingerichtet'), findsOneWidget);
        expect(find.text('Verwalten'), findsNWidgets(3));
        expect(find.text('Einrichten'), findsOneWidget);
        expect(find.text('Wiederherstellungscodes'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        client.close();
      },
    );
  }
}
