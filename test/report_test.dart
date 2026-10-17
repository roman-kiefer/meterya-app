import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meterya_app/l10n/app_localizations.dart';
import 'package:meterya_app/l10n/app_localizations_en.dart';
import 'package:meterya_app/l10n/app_localizations_de.dart';
import 'package:meterya_app/models.dart';
import 'package:meterya_app/report.dart';
import 'package:meterya_app/report_actions.dart';
import 'package:meterya_app/report_delivery.dart';
import 'package:meterya_app/report_view_model.dart';
import 'package:meterya_app/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const workspace = Workspace('ws', 'Haushalt', 'USER');
final exportedAt = DateTime.utc(2026, 10, 5, 12, 0);

AnnualSummary summary({int version = 9}) => AnnualSummary(
  2026,
  false,
  true,
  '100',
  '1234567890123456789',
  ['MEASUREMENT_GAP', 'UNIT_PRICE_GAP'],
  const [
    AnnualPosition(
      'i',
      'IMPORT',
      'kWh',
      '0.666667',
      '2026-01-01',
      '2026-01-03',
      '1234567890123456689',
      true,
      false,
    ),
    AnnualPosition(
      'e',
      'EXPORT',
      'kWh',
      '0.000000',
      '',
      '',
      null,
      false,
      false,
    ),
  ],
  pointVersion: version,
  calculationVersion: 1,
);

Point point({int version = 9, String name = 'OG Zähler'}) => Point(
  'point-123',
  name,
  'SN 123',
  version,
  const [Register('i', 'IMPORT', 'kWh'), Register('e', 'EXPORT', 'kWh')],
  const [
    Reading('2027-02-01', '104.000000', 'i', id: 'irrelevant-after'),
    Reading('2027-01-03', '103.000000', 'i', id: 'boundary-after'),
    Reading('2026-01-03', '100.666667', 'i', id: 'inside'),
    Reading('2025-12-31', '100.000000', 'i', id: 'boundary-before'),
    Reading('2025-10-01', '99.000000', 'i', id: 'irrelevant-before'),
  ],
  tariffs: const Tariffs(
    [Price('2025-01-01', '', 1000, 'BASE', 'MONTH')],
    [
      Price('2025-12-01', '2026-01-01', 20000, 'IMPORT', ''),
      Price('2026-01-01', '2027-01-01', 31000, 'IMPORT', ''),
      Price('2027-01-01', '', 40000, 'IMPORT', ''),
    ],
  ),
);

class CapturingDelivery implements ReportDelivery {
  final files = <ReportFile>[];
  bool fail = false;
  @override
  Future<void> save(ReportFile file) async {
    if (fail) {
      throw StateError('download failed');
    }
    files.add(file);
  }
}

Widget localized(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  setUpAll(() => initializeDateFormatting('de'));
  test(
    'English HTML report uses translated labels and exact decimal amounts',
    () {
      final report = BillingReport(workspace, point(), summary(), exportedAt);
      final html = report
          .render(ReportFormat.html, AppLocalizationsEn())
          .content;
      expect(html, contains('<html lang="en">'));
      expect(html, contains('Billing report'));
      expect(html, contains('Incomplete year'));
      expect(html, contains('12345678901234567.89 €'));
      expect(html, isNot(contains('12345678901234567,89 €')));
      final data =
          jsonDecode(
                report.render(ReportFormat.json, AppLocalizationsEn()).content,
              )
              as Map<String, dynamic>;
      expect(data['net_cents'], '1234567890123456789');
      expect((data['positions'] as List).first['quantity'], '0.666667');
    },
  );
  test('report retains exact API money and relevant neighbouring readings', () {
    final report = BillingReport(workspace, point(), summary(), exportedAt);
    final data =
        jsonDecode(
              report.render(ReportFormat.json, AppLocalizationsDe()).content,
            )
            as Map<String, dynamic>;
    expect(data['net_cents'], '1234567890123456789');
    expect((data['positions'] as List).first['quantity'], '0.666667');
    expect((data['positions'] as List).last['quantity'], isNull);
    expect((data['positions'] as List).last['cents'], isNull);
    expect(data['point']['version'], 9);
    expect(data['calculation_version'], 1);
    expect(data['exported_at'], '2026-10-05T12:00:00.000Z');
    expect((data['readings'] as List).map((r) => r['id']), [
      'boundary-before',
      'inside',
      'boundary-after',
    ]);
    expect((data['prices'] as List).map((p) => p['cents']), [1000, 31000]);
    expect(data['complete'], isFalse);
    final output = Platform.environment['METERYA_REPORT_FIXTURE_DIR'];
    if (output != null) {
      Directory(output).createSync(recursive: true);
      for (final format in ReportFormat.values) {
        final file = report.render(format, AppLocalizationsDe());
        File(
          '$output/test-abrechnungsbericht.${format.name}',
        ).writeAsStringSync(file.content);
      }
    }
  });

  test('HTML escapes user text and labels partial values and estimates', () {
    final p = point(name: '<script>alert("x")</script> & Haus');
    final file = BillingReport(
      const Workspace('ws', '<img src=x onerror=alert(1)>', 'ADMIN'),
      p,
      summary(),
      exportedAt,
    ).render(ReportFormat.html, AppLocalizationsDe());
    expect(file.content, contains('&lt;script&gt;'));
    expect(file.content, contains('&lt;img src=x onerror=alert(1)&gt;'));
    expect(file.content, contains('&amp; Haus'));
    expect(file.content, isNot(contains('<script>')));
    expect(file.content, isNot(contains('<img')));
    expect(file.content, contains('Unvollständiges Jahr'));
    expect(file.content, contains('Zeitanteilig geschätzt'));
    expect(file.content, contains('Noch nicht berechenbar'));
    expect(file.content, contains('12345678901234567,89 €'));
    expect(file.content, contains('Datenversion 9'));
    expect(file.content, isNot(contains('<td>0 kWh</td>')));
  });

  test('mismatched point version cannot export a report', () async {
    final delivery = CapturingDelivery();
    final model = ReportViewModel(
      workspace,
      point(version: 10),
      summary(),
      delivery,
    );
    expect(
      await model.export(ReportFormat.html, AppLocalizationsDe()),
      isFalse,
    );
    expect(model.error, 'REPORT_UNAVAILABLE');
    expect(delivery.files, isEmpty);
    model.dispose();
  });

  test(
    'report upload sends CSRF and versions before triggering native HTTP download',
    () async {
      final path =
          '/api/v1/workspaces/ws/points/point-123/reports/2026/download';
      const id = '11111111-1111-4111-8111-111111111111';
      var uploaded = false;
      String? downloaded;
      final client = MockClient((request) async {
        expect(request.url.path, path);
        expect(request.method, 'POST');
        expect(request.headers['X-CSRF-Token'], 'csrf');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['expected_version'], 9);
        expect(body['calculation_version'], 1);
        expect(body['format'], 'html');
        expect(body['content'], contains('24 kWh'));
        uploaded = true;
        return http.Response(jsonEncode({'download_url': '$path/$id'}), 201);
      });
      final api = ApiService(client, Uri.parse('http://localhost:8080'))
        ..csrf = 'csrf';
      final delivery = ServerReportDelivery(
        api,
        workspace,
        point(),
        summary(),
        download: (url, name) {
          expect(uploaded, isTrue);
          downloaded = url;
          expect(name, 'report.html');
        },
      );
      await delivery.save(
        const ReportFile('report.html', 'text/html', '<h1>24 kWh</h1>'),
      );
      expect(downloaded, '$path/$id');
      client.close();
    },
  );

  test(
    'download address stays within its authenticated report route',
    () async {
      final client = MockClient(
        (_) async => http.Response(
          '{"download_url":"https://example.test/report"}',
          201,
        ),
      );
      final delivery = ServerReportDelivery(
        ApiService(client, Uri.parse('http://localhost:8080')),
        workspace,
        point(),
        summary(),
        download: (_, _) => fail('external navigation'),
      );
      await expectLater(
        delivery.save(const ReportFile('report.html', 'text/html', 'test')),
        throwsStateError,
      );
      client.close();
    },
  );

  testWidgets(
    'USER can export both files and refreshed data replaces old snapshot',
    (tester) async {
      final delivery = CapturingDelivery();
      await tester.pumpWidget(
        localized(
          ReportActions(
            workspace: workspace,
            point: point(),
            summary: summary(),
            delivery: delivery,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bericht herunterladen (HTML)'));
      await tester.pumpAndSettle();
      expect(delivery.files.single.name, 'meterya-2026-point-123-v9.html');
      await tester.tap(find.text('Datendatei herunterladen (JSON)'));
      await tester.pumpAndSettle();
      expect(jsonDecode(delivery.files.last.content)['point']['version'], 9);
      await tester.pumpWidget(
        localized(
          ReportActions(
            workspace: workspace,
            point: point(version: 10, name: 'Neuer Stand'),
            summary: summary(version: 10),
            delivery: delivery,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bericht herunterladen (HTML)'));
      await tester.pumpAndSettle();
      expect(delivery.files.last.name, 'meterya-2026-point-123-v10.html');
      expect(delivery.files.last.content, contains('Neuer Stand'));
    },
  );

  testWidgets('failed download is visible and a retry clears the error', (
    tester,
  ) async {
    final delivery = CapturingDelivery()..fail = true;
    await tester.pumpWidget(
      localized(
        ReportActions(
          workspace: workspace,
          point: point(),
          summary: summary(),
          delivery: delivery,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bericht herunterladen (HTML)'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Der Bericht konnte nicht heruntergeladen werden. Bitte erneut versuchen.',
      ),
      findsOneWidget,
    );
    delivery.fail = false;
    await tester.tap(find.text('Bericht herunterladen (HTML)'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Der Bericht konnte nicht heruntergeladen werden. Bitte erneut versuchen.',
      ),
      findsNothing,
    );
    expect(delivery.files, hasLength(1));
  });
}
