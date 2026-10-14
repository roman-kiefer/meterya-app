import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meterya_app/api_service.dart';
import 'package:meterya_app/l10n/app_localizations.dart';
import 'package:meterya_app/models.dart';
import 'package:meterya_app/photo_gallery.dart';
import 'package:meterya_app/photo_model.dart';
import 'package:meterya_app/reading_change_dialog.dart';
import 'package:meterya_app/reading_photo_evidence.dart';
import 'package:meterya_app/repository.dart';
import 'package:meterya_app/view_model.dart';

void main() {
  for (final width in [360.0, 1280.0]) {
    for (final action in ['view', 'correct', 'retract']) {
      testWidgets('$action shows booked values and matching photo at $width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final requests = <String>[];
        final api = ApiService(
          MockClient((r) async {
            requests.add(r.url.path);
            return http.Response.bytes(
              base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
              ),
              200,
            );
          }),
          Uri.parse('http://localhost'),
        );
        ReadingPhoto photo(String id, String reading) => ReadingPhoto(
          id: id,
          readingId: reading,
          pointId: 'point',
          registerId: 'export',
          date: '2026-10-13',
          value: '81.000000',
          status: 'CORRECTED',
          previewURL: '/preview/$id',
          originalURL: '/original/$id',
          width: 1,
          height: 1,
        );
        final own = photo('own', 'reading');
        const reading = Reading(
          '2026-10-14',
          '84.000000',
          'export',
          id: 'reading',
        );
        final point = Point(
          'point',
          'Z2',
          'Meter-123',
          5,
          [const Register('export', 'EXPORT', 'kWh')],
          [reading],
          photos: [own, photo('foreign', 'other-reading')],
        );
        final model = ViewModel(Repository(api))
          ..signedIn = true
          ..workspace = const Workspace('workspace', 'House', 'MODERATOR');
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: width == 360 ? Brightness.dark : Brightness.light,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: action == 'view'
                  ? PhotoGallery(
                      api: api,
                      photos: [own],
                      point: point,
                      reading: reading,
                    )
                  : ReadingChangeDialog(
                      model: model,
                      point: point,
                      reading: reading,
                      retract: action == 'retract',
                    ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Gebuchte Ablesung'), findsOneWidget);
        expect(find.text('Z2 · Meter-123'), findsOneWidget);
        expect(find.text('Register: Einspeisung · 2.8.0'), findsOneWidget);
        expect(find.text('Zählerstand: 84 kWh'), findsOneWidget);
        expect(find.text('Angaben bei Fotozuordnung'), findsOneWidget);
        expect(find.text('2026-10-13 · 81'), findsOneWidget);
        await tester.ensureVisible(find.byType(ReadingPhotoPreview));
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsOneWidget);
        expect(requests, ['/preview/own']);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }
  }
}
