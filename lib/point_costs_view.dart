import 'report_actions.dart';
import 'main.dart' show errorText;
import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'models.dart';
import 'view_model.dart';
import 'monthly_overview_view.dart';

/// Shows the monthly chart and table without duplicating their yearly totals.
class PointCostsView extends StatelessWidget {
  final ViewModel model;
  final Point point;
  final int? year;
  const PointCostsView({
    super.key,
    required this.model,
    required this.point,
    required this.year,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final year = this.year;
    final summary = point.annual?.where((s) => s.year == year).firstOrNull;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (point.isVirtual) Text(l.virtualCalculated),
        if (point.isVirtualHeat)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(l.virtualGridCostsHelp),
          ),
        for (final flag in point.virtualFlags) Text(errorText(l, flag)),
        if (year == null)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l.noBillingReadings),
          )
        else ...[
          if (summary?.estimated == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(l.estimatedAllocation),
            ),
          for (final warning in summary?.warnings ?? <String>[])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(switch (warning) {
                'COVERAGE_DIFFERS' => l.virtualCoverageDiffers,
                'MEASUREMENT_GAP' => l.measurementGap,
                'UNIT_PRICE_GAP' => l.unitPriceGap,
                'BASE_PRICE_GAP' => l.basePriceGap,
                _ => l.partialYear,
              }),
            ),
          MonthlyOverviewView(point: point, summary: summary, year: year),
          if (summary != null && model.workspace != null)
            ReportActions(
              workspace: model.workspace!,
              point: point,
              summary: summary,
              api: model.repository.api,
            ),
        ],
      ],
    );
  }
}
