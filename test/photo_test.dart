import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meterya_app/api_service.dart';
import 'package:meterya_app/backup_upload.dart';
import 'package:meterya_app/backup_view_model.dart';
import 'package:meterya_app/l10n/app_localizations.dart';
import 'package:meterya_app/models.dart';
import 'package:meterya_app/photo_entry_view.dart';
import 'package:meterya_app/photo_view_model.dart';
import 'package:meterya_app/overview_frame.dart';
import 'package:meterya_app/profile_menu.dart';
import 'package:meterya_app/reading_entry.dart';
import 'package:meterya_app/repository.dart';
import 'package:meterya_app/view_model.dart';

final image = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
);
Map<String, dynamic> proposal({bool attach = false}) => {
  'photo': {
    'id': 'photo',
    'preview_url': '/preview',
    'original_url': '/original',
    'preview_width': 1,
    'preview_height': 1,
  },
  'point_id': 'point',
  'register_id': 'register',
  'date': '2026-10-12',
  'value': '12.123456',
  'expected_version': 5,
  'can_create': !attach,
  'can_attach': attach,
  if (attach) 'existing_reading_id': 'reading',
  'flags': <String>[],
};
void main() {
  testWidgets('photo page saves edits and isolates three recognition areas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAGQAAABQCAIAAABga0e4AAAAvUlEQVR4nO3QQQ0AIAzAwPk3DRbWFyG5U9B0DmvzOuAnZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFZgVmBWYFF5Z6Z7T8fzcqAAAAAElFTkSuQmCC',
    );
    final requests = <http.Request>[];
    final api = ApiService(
      MockClient((r) async {
        requests.add(r);
        if (r.method == 'GET' || r.url.path.endsWith('/working')) {
          return http.Response.bytes(bytes, 200);
        }
        if (r.url.path.endsWith('/confirm')) return http.Response('{}', 201);
        final data = proposal();
        data['photo'] = {
          ...(data['photo'] as Map<String, dynamic>),
          'preview_width': 100,
          'preview_height': 80,
        };
        if (r.url.path.endsWith('/analyze')) {
          final input = jsonDecode(r.body) as Map<String, dynamic>;
          data['point_id'] = input['target'] == 'serial'
              ? 'point'
              : input['point_id'];
          data['register_id'] = input['target'] == 'register'
              ? 'register'
              : input['register_id'];
          data['value'] = input['target'] == 'value'
              ? '12.123456'
              : input['value'];
        } else {
          data['point_id'] = null;
          data['register_id'] = null;
          data['value'] = '';
        }
        return http.Response(jsonEncode(data), 200);
      }),
      Uri.parse('http://localhost:8080'),
    );
    final model = ViewModel(Repository(api))
      ..signedIn = true
      ..workspace = const Workspace('workspace', 'House', 'USER')
      ..points = [
        Point('point', 'Meter', 'serial', 5, [
          const Register('register', 'IMPORT', 'kWh'),
        ], []),
      ];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PhotoEntryView(model: model, picker: (_) => Future.value(bytes)),
      ),
    );
    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
    }

    Future<void> mark() async {
      final finder = find.byKey(const ValueKey('photo-working-image'));
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      final rect = tester.getRect(finder);
      final gesture = await tester.startGesture(
        rect.topLeft + Offset(rect.width * .15, rect.height * .15),
      );
      await gesture.moveTo(
        rect.topLeft + Offset(rect.width * .3, rect.height * .3),
      );
      await tester.pump();
      await gesture.moveTo(
        rect.topLeft + Offset(rect.width * .85, rect.height * .85),
      );
      await gesture.up();
      await tester.pumpAndSettle();
    }

    await tap(find.text('Foto auswählen'));
    await mark();
    await tap(find.widgetWithText(OutlinedButton, 'Zuschneiden'));
    await tap(find.widgetWithText(OutlinedButton, 'Rechts drehen'));
    await tap(find.widgetWithText(FilledButton, 'Weiter'));
    for (final label in ['Zählernummer', 'Register', 'Zählerstand']) {
      await tap(find.widgetWithText(ChoiceChip, label));
      await mark();
      await tap(find.widgetWithText(FilledButton, 'Erkennen'));
    }
    await tester.ensureVisible(find.byType(TextField).last);
    await tester.enterText(find.byType(TextField).last, '13.123456');
    await tester.pumpAndSettle();
    await tap(find.widgetWithText(FilledButton, 'Weiter'));
    await tap(find.byType(CheckboxListTile));
    await tap(find.widgetWithText(FilledButton, 'Speichern'));
    final recognized = requests
        .where((r) => r.url.path.endsWith('/analyze'))
        .map((r) => jsonDecode(r.body) as Map<String, dynamic>)
        .toList();
    expect(recognized.map((r) => r['target']).whereType<String>(), [
      'serial',
      'register',
      'value',
    ]);
    expect(recognized.last['value'], '13.123456');
    expect(recognized.last.containsKey('crop'), false);
    final confirmed =
        jsonDecode(
              requests.singleWhere((r) => r.url.path.endsWith('/confirm')).body,
            )
            as Map<String, dynamic>;
    expect(confirmed['value'], '13.123456');
    expect((confirmed['edits'] as List).length, 2);
    expect((confirmed['edits'] as List).last, {'rotation': 90});
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  test(
    'photo review keeps exact API values, version and retry identity',
    () async {
      final requests = <http.Request>[];
      final api = ApiService(
        MockClient((r) async {
          requests.add(r);
          if (r.method == 'GET') return http.Response.bytes(image, 200);
          if (r.url.path.endsWith('/confirm')) return http.Response('{}', 201);
          return http.Response(jsonEncode(proposal(attach: true)), 201);
        }),
        Uri.parse('http://localhost:8080'),
      )..csrf = 'csrf';
      final vm = PhotoViewModel(Repository(api), 'workspace');
      expect(await vm.upload(Uint8List.fromList([1, 2, 3])), true);
      expect(vm.proposal!.value, '12.123456');
      expect(vm.proposal!.version, 5);
      expect(vm.proposal!.canAttach, true);
      final key = vm.confirmKey;
      expect(
        await vm.save({
          'point_id': 'point',
          'register_id': 'register',
          'date': '2026-10-12',
          'value': vm.proposal!.value,
          'existing_reading_id': 'reading',
          'expected_version': vm.proposal!.version,
        }),
        true,
      );
      final saved = requests.last;
      expect(saved.headers['Idempotency-Key'], key);
      expect(saved.headers['X-CSRF-Token'], 'csrf');
      expect(jsonDecode(saved.body)['value'], '12.123456');
      await vm.discard();
      expect(requests.where((r) => r.url.path.endsWith('/discard')), isEmpty);
      vm.dispose();
    },
  );
  for (final width in [360.0, 1280.0]) {
    testWidgets(
      'reading method and photo page retain shared navigation at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final model =
            ViewModel(
                Repository(
                  ApiService(
                    MockClient((r) async => http.Response('{}', 200)),
                    Uri.parse('http://localhost'),
                  ),
                ),
              )
              ..signedIn = true
              ..workspace = const Workspace('workspace', 'House', 'MODERATOR')
              ..points = [
                Point('point', 'Meter', 'serial', 5, [
                  const Register('register', 'IMPORT', 'kWh'),
                ], []),
              ];
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showReadingEntry(context, model),
                  child: const Text('Start'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Start'));
        await tester.pumpAndSettle();
        void expectFrame() {
          expect(find.byType(WorkspaceScaffold), findsOneWidget);
          expect(find.byType(ProfileMenu), findsOneWidget);
          expect(
            find.byKey(const ValueKey('workspace-switch')),
            findsOneWidget,
          );
          expect(find.byType(BackButton), findsNothing);
          expect(
            width < 900
                ? find.byTooltip('Menü öffnen')
                : find.byType(NavigationRail),
            findsOneWidget,
          );
        }

        expectFrame();
        await tester.tap(
          find.descendant(
            of: find.byType(Card),
            matching: find.text('Ablesung per Foto'),
          ),
        );
        await tester.pumpAndSettle();
        expectFrame();
        expect(find.text('Foto auswählen'), findsOneWidget);
        if (width < 900) {
          await tester.tap(find.byTooltip('Menü öffnen'));
          await tester.pumpAndSettle();
        }
        await tester.tap(
          find.descendant(
            of: find.byType(width < 900 ? NavigationDrawer : NavigationRail),
            matching: find.text('Übersicht'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Start'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
    for (final brightness in Brightness.values) {
      testWidgets('photo requires review at $width in $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final requests = <http.Request>[];
        final api = ApiService(
          MockClient((r) async {
            requests.add(r);
            if (r.method == 'GET') return http.Response.bytes(image, 200);
            if (r.url.path.endsWith('/analyze')) {
              return http.Response(
                jsonEncode({
                  ...proposal(),
                  'value': jsonDecode(r.body)['value'],
                  'expected_version': 6,
                }),
                200,
              );
            }
            if (r.url.path.endsWith('/confirm')) {
              return http.Response('{}', 201);
            }
            return http.Response(jsonEncode(proposal()), 201);
          }),
          Uri.parse('http://localhost:8080'),
        );
        final model = ViewModel(Repository(api))
          ..signedIn = true
          ..workspace = const Workspace('workspace', 'House', 'USER')
          ..points = [
            Point('point', 'Meter', 'serial', 5, [
              const Register('register', 'IMPORT', 'kWh'),
            ], []),
          ];
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PhotoEntryView(
                model: model,
                picker: (_) => Future.value(Uint8List.fromList([1, 2, 3])),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Foto auswählen'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        await tester.ensureVisible(find.widgetWithText(FilledButton, 'Weiter'));
        await tester.tap(find.widgetWithText(FilledButton, 'Weiter'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.widgetWithText(FilledButton, 'Weiter'));
        await tester.tap(find.widgetWithText(FilledButton, 'Weiter'));
        await tester.pumpAndSettle();
        final save = find.widgetWithText(FilledButton, 'Speichern');
        expect(tester.widget<FilledButton>(save).onPressed, isNull);
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pump();
        expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
        await tester.ensureVisible(find.byType(TextField).last);
        await tester.enterText(find.byType(TextField).last, '13.123456');
        await tester.pump();
        expect(tester.widget<FilledButton>(save).onPressed, isNull);
        expect(
          tester
              .widget<CheckboxListTile>(find.byType(CheckboxListTile))
              .onChanged,
          isNotNull,
        );
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pump();
        expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        final analysis = requests.singleWhere(
          (r) => r.url.path.endsWith('/analyze'),
        );
        final confirmation = requests.singleWhere(
          (r) => r.url.path.endsWith('/confirm'),
        );
        expect(jsonDecode(analysis.body)['value'], '13.123456');
        expect(jsonDecode(confirmation.body)['value'], '13.123456');
        expect(jsonDecode(confirmation.body)['expected_version'], 6);
        expect(
          requests.indexOf(analysis),
          lessThan(requests.indexOf(confirmation)),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }
  }
  test(
    'ZIP preview and restore use prepared file, checksum and confirmation',
    () async {
      final requests = <http.Request>[];
      final api = ApiService(
        MockClient((r) async {
          requests.add(r);
          return http.Response('{}', 200);
        }),
        Uri.parse('http://localhost:8080'),
      )..csrf = 'csrf';
      final model = BackupViewModel(api);
      final file = BackupUpload(
        'backup.zip',
        (_) async => {
          'id': 'job',
          'status': 'READY',
          'info': {'sha256': 'digest', 'contains_photos': true, 'photos': 2},
        },
      );
      expect(await model.validateArchive(file), true);
      expect(model.preview!['photos'], 2);
      expect(model.contents, isNull);
      expect(await model.restore(), true);
      expect(
        requests.single.url.path,
        '/api/v1/operator/backup/jobs/job/restore',
      );
      expect(requests.single.headers['X-Backup-Confirm'], 'RESTORE');
      expect(requests.single.headers['X-Backup-SHA256'], 'digest');
      model.dispose();
    },
  );
}
