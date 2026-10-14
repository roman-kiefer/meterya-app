import 'api_service.dart';
import 'models.dart';
import 'report.dart';
import 'report_delivery_stub.dart'
    if (dart.library.js_interop) 'report_delivery_web.dart'
    as platform;

void downloadReportURL(String url, String name) =>
    platform.downloadReportURL(url, name);

ReportDelivery defaultReportDelivery(
  ApiService? api,
  Workspace workspace,
  Point point,
  AnnualSummary summary,
) => api == null
    ? _UnavailableDelivery()
    : ServerReportDelivery(api, workspace, point, summary);

class _UnavailableDelivery implements ReportDelivery {
  @override
  Future<void> save(ReportFile file) async =>
      throw StateError('Report API unavailable');
}

class ServerReportDelivery implements ReportDelivery {
  final ApiService api;
  final Workspace workspace;
  final Point point;
  final AnnualSummary summary;
  final void Function(String url, String name) download;
  ServerReportDelivery(
    this.api,
    this.workspace,
    this.point,
    this.summary, {
    void Function(String, String)? download,
  }) : download = download ?? platform.downloadReportURL;
  @override
  Future<void> save(ReportFile file) async {
    final endpoint =
        '/api/v1/workspaces/${workspace.id}/points/${point.id}/reports/${summary.year}/download';
    final data =
        await api.request(
              endpoint,
              body: {
                'expected_version': point.version,
                'data_version': ?point.dataVersion,
                'calculation_version': summary.calculationVersion,
                'format': file.name.endsWith('.html') ? 'html' : 'json',
                'content': file.content,
              },
            )
            as Map<String, dynamic>;
    final url = data['download_url'] as String;
    if (!RegExp(
      '^${RegExp.escape(endpoint)}/[a-fA-F0-9-]{36}\$',
    ).hasMatch(url)) {
      throw StateError('Invalid download address');
    }
    download(url, file.name);
  }
}
