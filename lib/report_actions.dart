import 'package:flutter/material.dart';
import 'api_service.dart';
import 'l10n/app_localizations.dart';
import 'models.dart';
import 'report.dart';
import 'report_delivery.dart';
import 'report_view_model.dart';

class ReportActions extends StatefulWidget {
  final Workspace workspace;
  final Point point;
  final AnnualSummary summary;
  final ReportDelivery? delivery;
  final ApiService? api;
  const ReportActions({
    super.key,
    required this.workspace,
    required this.point,
    required this.summary,
    this.delivery,
    this.api,
  });
  @override
  State<ReportActions> createState() => _ReportActionsState();
}

class _ReportActionsState extends State<ReportActions> {
  late ReportViewModel model;
  @override
  void initState() {
    super.initState();
    _create();
  }

  void _create() {
    model = ReportViewModel(
      widget.workspace,
      widget.point,
      widget.summary,
      widget.delivery ??
          defaultReportDelivery(
            widget.api,
            widget.workspace,
            widget.point,
            widget.summary,
          ),
    );
  }

  @override
  void didUpdateWidget(ReportActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.point != widget.point ||
        oldWidget.summary != widget.summary ||
        oldWidget.workspace != widget.workspace ||
        oldWidget.delivery != widget.delivery ||
        oldWidget.api != widget.api) {
      model.dispose();
      _create();
    }
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (model.busy) const LinearProgressIndicator(),
            Text(l.reportDownloadHelp),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: model.busy
                      ? null
                      : () => model.export(ReportFormat.html, l),
                  icon: const Icon(Icons.description_outlined),
                  label: Text(l.downloadReport),
                ),
                TextButton.icon(
                  onPressed: model.busy
                      ? null
                      : () => model.export(ReportFormat.json, l),
                  icon: const Icon(Icons.download_outlined),
                  label: Text(l.downloadReportData),
                ),
              ],
            ),
            if (model.error != null)
              Text(switch (model.error) {
                'REPORT_UNAVAILABLE' => l.reportUnavailable,
                'REPORT_API_UNAVAILABLE' => l.reportApiUnavailable,
                'PERMISSION_DENIED' => l.permissionError,
                _ => l.reportExportFailed,
              }, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
    );
  }
}
