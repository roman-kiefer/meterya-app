import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meterya_app/api_service.dart';
import 'package:meterya_app/backup_view.dart';
import 'package:meterya_app/backup_view_model.dart';
import 'package:meterya_app/l10n/app_localizations.dart';
import 'package:meterya_app/repository.dart';
import 'package:meterya_app/view_model.dart';

const rawBackup = '{"sequence":9007199254740993,"value":"123456789.123456"}';
final preview = {
  'sha256': 'digest',
  'created_at': '2026-10-06T06:00:00Z',
  'workspaces': 2,
  'points': 1,
  'readings': 34,
  'events': 40,
};

void main() {
  test(
    'raw backup stays exact and failed selection clears prior preview',
    () async {
      var fail = false;
      final requests = <http.Request>[];
      final api = ApiService(
        MockClient((r) async {
          requests.add(r);
          expect(r.body, rawBackup);
          expect(r.headers['X-CSRF-Token'], 'csrf');
          return http.Response(
            jsonEncode(fail ? {'code': 'BACKUP_INVALID'} : preview),
            fail ? 400 : 200,
          );
        }),
        Uri.parse('http://localhost:8080/'),
      )..csrf = 'csrf';
      final model = BackupViewModel(api);
      expect(await model.restore(), false);
      expect(requests, isEmpty);
      expect(await model.validate('backup.json', rawBackup), true);
      fail = true;
      expect(await model.validate('broken.json', rawBackup), false);
      expect(model.preview, isNull);
      expect(await model.restore(), false);
      fail = false;
      await model.validate('backup.json', rawBackup);
      expect(await model.restore(), true);
      expect(requests.last.headers['X-Backup-SHA256'], 'digest');
      expect(requests.last.headers['X-Backup-Confirm'], 'RESTORE');
      expect(model.restored, true);
      expect(api.csrf, isNull);
    },
  );
  testWidgets('restore stays disabled until preview and typed confirmation', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final api = ApiService(
      MockClient((r) async {
        requests.add(r);
        return http.Response(jsonEncode(preview), 200);
      }),
      Uri.parse('http://localhost:8080/'),
    );
    final model = ViewModel(Repository(api));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BackupView(
          model: model,
          pickFile: () async => (name: 'backup.json', contents: rawBackup),
        ),
      ),
    );
    expect(find.text('Datenbestand ersetzen'), findsNothing);
    await tester.tap(find.text('Sicherung auswählen und prüfen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('34 Ablesungen'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Datenbestand ersetzen'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final button = find.widgetWithText(FilledButton, 'Datenbestand ersetzen');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'WIEDERHERSTELLEN');
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    expect(requests.length, 1);
    expect(requests.single.url.path.endsWith('/validate'), true);
  });
}
