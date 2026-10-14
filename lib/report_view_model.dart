import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'l10n/app_localizations.dart';
import 'models.dart';
import 'report.dart';

class ReportViewModel extends ChangeNotifier {
  final Workspace workspace;
  final Point point;
  final AnnualSummary summary;
  final ReportDelivery delivery;
  final DateTime Function() clock;
  String? error;
  bool busy = false;
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  ReportViewModel(
    this.workspace,
    this.point,
    this.summary,
    this.delivery, {
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  Future<bool> export(ReportFormat format, AppLocalizations labels) async {
    if (busy) {
      return false;
    }
    busy = true;
    error = null;
    _notify();
    try {
      final report = BillingReport(workspace, point, summary, clock());
      await delivery.save(report.render(format, labels));
      return true;
    } on ApiException catch (e) {
      error = switch (e.code) {
        'AGGREGATE_VERSION_CONFLICT' => 'REPORT_UNAVAILABLE',
        'PERMISSION_DENIED' ||
        'MFA_REQUIRED' ||
        'AUTHENTICATION_REQUIRED' => 'PERMISSION_DENIED',
        'RESOURCE_NOT_FOUND' => 'REPORT_API_UNAVAILABLE',
        _ => 'REPORT_EXPORT_FAILED',
      };
      return false;
    } catch (_) {
      error =
          summary.pointVersion != point.version ||
              (summary.calculationVersion == null ||
                  summary.calculationVersion! < 1)
          ? 'REPORT_UNAVAILABLE'
          : 'REPORT_EXPORT_FAILED';
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
