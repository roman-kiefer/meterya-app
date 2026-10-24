import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meterya_app/api_service.dart';
import 'package:meterya_app/l10n/app_localizations.dart';
import 'package:meterya_app/login_view.dart';
import 'package:meterya_app/main.dart';
import 'package:meterya_app/models.dart';
import 'package:meterya_app/overview_frame.dart';
import 'package:meterya_app/repository.dart';
import 'package:meterya_app/version_footer.dart';
import 'package:meterya_app/view_model.dart';

ViewModel versionModel(Future<http.Response> Function(http.Request) handler) =>
    ViewModel(
      Repository(
        ApiService(MockClient(handler), Uri.parse('https://example.test')),
      ),
    );

Widget localized(Widget child, {String language = 'en', double scale = 1}) =>
    MaterialApp(
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: child,
    );

void main() {
  test('UI version matches the embedded release tag or local default', () {
    expect(
      uiVersion,
      const String.fromEnvironment('EXPECTED_UI_VERSION', defaultValue: 'dev'),
    );
  });
  for (final version in ['v1.2.1', 'dev']) {
    test(
      'version endpoint returns $version independently of UI version',
      () async {
        final model = versionModel((request) async {
          expect(request.method, 'GET');
          expect(request.url.toString(), 'https://example.test/api/v1/version');
          return http.Response('{"version":"$version"}', 200);
        });
        addTearDown(model.dispose);
        await model.loadVersion();
        expect(model.apiVersion, version);
        expect(model.versionLoading, isFalse);
      },
    );
  }

  for (final (status, body) in [
    (404, 'Not found'),
    (500, '{}'),
    (302, '{}'),
    (200, '<html>old proxy</html>'),
    (200, '{}'),
    (200, '[]'),
    (200, 'null'),
    (200, '{"version":42}'),
    (200, '{"version":null}'),
    (200, '{"version":""}'),
    (200, '{"version":"  "}'),
  ]) {
    test('unavailable for HTTP $status and $body', () async {
      final model = versionModel((_) async => http.Response(body, status));
      addTearDown(model.dispose);
      await model.loadVersion();
      expect(model.apiVersion, isNull);
      expect(model.versionLoading, isFalse);
      expect(model.busy, isFalse);
      expect(model.error, isNull);
    });
  }

  test(
    'network failure does not affect application error or busy state',
    () async {
      final model = versionModel(
        (_) async => throw http.ClientException('offline'),
      );
      addTearDown(model.dispose);
      model.error = 'existing error';
      model.busy = true;
      await model.loadVersion();
      expect(model.versionLoading, isFalse);
      expect(model.apiVersion, isNull);
      expect(model.error, 'existing error');
      expect(model.busy, isTrue);
    },
  );

  testWidgets('timeout after ten seconds ignores late success', (tester) async {
    final response = Completer<http.Response>();
    final model = versionModel((_) => response.future);
    addTearDown(model.dispose);
    final request = model.loadVersion();
    await tester.pump(const Duration(seconds: 9));
    expect(model.versionLoading, isTrue);
    await tester.pump(const Duration(seconds: 1));
    await request;
    expect(model.versionLoading, isFalse);
    expect(model.apiVersion, isNull);
    response.complete(http.Response('{"version":"v9.9.9"}', 200));
    await tester.pump();
    expect(model.apiVersion, isNull);
  });

  test('disposed model ignores completion', () async {
    final response = Completer<http.Response>();
    final model = versionModel((_) => response.future);
    var notifications = 0;
    model.addListener(() => notifications++);
    final request = model.loadVersion();
    model.dispose();
    response.complete(http.Response('{"version":"dev"}', 200));
    await request;
    expect(notifications, 0);
  });

  test(
    'pending version does not block initialization and is fetched only once',
    () async {
      final response = Completer<http.Response>();
      var calls = 0;
      final model = versionModel((request) async {
        if (request.url.path == '/api/v1/version') {
          calls++;
          return response.future;
        }
        return http.Response('{"csrf_token":"token","workspaces":[]}', 200);
      });
      addTearDown(model.dispose);
      final first = model.loadVersion();
      await model.initialize();
      expect(model.signedIn, isTrue);
      expect(model.busy, isFalse);
      expect(model.versionLoading, isTrue);
      expect(model.loadVersion(), same(first));
      response.complete(http.Response('{"version":"v1.2.1"}', 200));
      await first;
      await model.initialize();
      await model.loadVersion();
      expect(calls, 1);
    },
  );

  testWidgets(
    'footer shows independent release versions and embedded UI default',
    (tester) async {
      await tester.pumpWidget(
        localized(
          const Scaffold(
            body: VersionFooter(ui: 'v1.2.3', apiVersion: 'v1.2.1'),
          ),
        ),
      );
      expect(find.text('UI: v1.2.3'), findsOneWidget);
      expect(find.text('API: v1.2.1'), findsOneWidget);
      await tester.pumpWidget(localized(const Scaffold(body: VersionFooter())));
      expect(find.text('UI: $uiVersion'), findsOneWidget);
    },
  );

  for (final language in ['de', 'en']) {
    for (final width in [360.0, 1280.0]) {
      testWidgets('login and navigation states at $width in $language', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final response = Completer<http.Response>();
        var calls = 0;
        final model = versionModel((_) {
          calls++;
          return response.future;
        });
        addTearDown(model.dispose);
        final request = model.loadVersion();
        await tester.pumpWidget(
          localized(Home(model: model), language: language),
        );
        expect(find.text('UI: $uiVersion'), findsOneWidget);
        expect(find.text('API: …'), findsOneWidget);
        response.complete(http.Response('old API', 404));
        await request;
        await tester.pump();
        final unavailable = language == 'de'
            ? 'nicht verfügbar'
            : 'unavailable';
        expect(find.text('API: $unavailable'), findsOneWidget);
        model.signedIn = true;
        await tester.pumpWidget(
          localized(
            WorkspaceScaffold(
              appBar: WorkspaceAppBar(model: model, title: const Text('Test')),
              body: AppNavigationFrame(
                model: model,
                child: const Text('Content'),
              ),
            ),
            language: language,
          ),
        );
        if (width < 900) {
          await tester.tap(find.byIcon(Icons.menu));
          await tester.pumpAndSettle();
        }
        expect(find.text('API: $unavailable'), findsOneWidget);
        expect(find.text('UI: $uiVersion'), findsOneWidget);
        expect(calls, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final width in [360.0, 1280.0]) {
    testWidgets(
      'short login keeps footer visible and sign-in reachable at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 320);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var signedIn = false;
        await tester.pumpWidget(
          localized(
            LoginView(
              busy: false,
              error: 'An authentication error',
              onLogin: () => signedIn = true,
              onLogout: () {},
              footer: const VersionFooter(apiVersion: 'dev'),
            ),
            scale: 2,
          ),
        );
        final footerPosition = tester.getRect(find.byType(VersionFooter));
        await tester.ensureVisible(find.byType(FilledButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(FilledButton));
        expect(signedIn, isTrue);
        expect(tester.getRect(find.byType(VersionFooter)), footerPosition);
        expect(find.text('API: dev').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('short navigation scrolls above fixed footer at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final response = Completer<http.Response>();
      final model = versionModel((_) => response.future);
      addTearDown(model.dispose);
      final request = model.loadVersion();
      model.signedIn = true;
      model.workspace = const Workspace('ws', 'Home', 'ADMIN');
      model.hasHeatConfiguration = true;
      await tester.pumpWidget(
        localized(
          WorkspaceScaffold(
            appBar: WorkspaceAppBar(
              model: model,
              title: const Text('Test'),
              showBillingYear: false,
            ),
            body: AppNavigationFrame(
              model: model,
              child: const Text('Content'),
            ),
          ),
          scale: 2,
        ),
      );
      if (width < 900) {
        await tester.tap(find.byIcon(Icons.menu));
        await tester.pumpAndSettle();
      }
      expect(find.text('API: …'), findsOneWidget);
      response.complete(http.Response('{"version":"v1.2.1"}', 200));
      await request;
      await tester.pump();
      final footer = find.byType(VersionFooter);
      final position = tester.getRect(footer);
      final navigation = find.byType(
        width < 900 ? NavigationDrawer : NavigationRail,
      );
      final scroll = find
          .descendant(of: navigation, matching: find.byType(Scrollable))
          .first;
      await tester.scrollUntilVisible(
        find.text('Audit log'),
        120,
        scrollable: scroll,
      );
      await tester.pumpAndSettle();
      expect(find.text('Audit log').hitTestable(), findsOneWidget);
      expect(tester.getRect(footer), position);
      expect(position.bottom, lessThanOrEqualTo(400));
      expect(find.text('API: v1.2.1').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
