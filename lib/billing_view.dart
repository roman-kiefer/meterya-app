import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'l10n/app_localizations.dart';
import 'models.dart';
import 'tariff_view.dart';
import 'report_actions.dart';
import 'api_service.dart';

class BillingView extends StatelessWidget {
  final Point point;
  final bool initiallyExpanded;
  final Workspace? workspace;
  final ApiService? api;
  const BillingView({
    super.key,
    required this.point,
    this.workspace,
    this.api,
    this.initiallyExpanded = false,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final format = DateFormat.yMd(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final summaries = point.annual;
    String money(String? cents) =>
        cents == null ? l.notCalculated : displayEuros(cents);
    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      title: Text(l.annualBilling),
      children: [
        if (summaries == null)
          ListTile(title: Text(l.billingUnavailable))
        else if (summaries.isEmpty)
          ListTile(title: Text(l.noBillingReadings))
        else
          for (final year in summaries)
            ExpansionTile(
              title: Text(year.year.toString()),
              subtitle: Text(
                '${year.complete ? l.completeYear : l.partialYear}${year.estimated ? ' · ${l.estimatedAllocation}' : ''}',
              ),
              children: [
                if (workspace != null)
                  ReportActions(
                    key: ValueKey('${point.id}-${year.year}'),
                    workspace: workspace!,
                    point: point,
                    summary: year,
                    api: api,
                  ),
                for (final warning in year.warnings)
                  ListTile(
                    title: Text(switch (warning) {
                      'MEASUREMENT_GAP' => l.measurementGap,
                      'UNIT_PRICE_GAP' => l.unitPriceGap,
                      'BASE_PRICE_GAP' => l.basePriceGap,
                      _ => l.partialYear,
                    }),
                  ),
                for (final position in year.positions)
                  ListTile(
                    title: Text(
                      position.from.isEmpty
                          ? priceCategory(l, position.direction)
                          : l.billingQuantity(
                              priceCategory(l, position.direction),
                              displayQuantity(position.quantity),
                              position.unit,
                            ),
                    ),
                    subtitle: Text(
                      position.from.isEmpty
                          ? l.noRegisterCoverage
                          : l.readingPeriod(
                              format.format(DateTime.parse(position.from)),
                              format.format(DateTime.parse(position.until)),
                            ),
                    ),
                  ),
                for (final position in year.positions)
                  ListTile(
                    title: Text(
                      position.direction == 'EXPORT'
                          ? l.exportRevenue
                          : l.positionCost(
                              priceCategory(l, position.direction),
                            ),
                    ),
                    subtitle: Text(money(position.cents)),
                  ),
                ListTile(
                  title: Text(l.baseCosts),
                  subtitle: Text(money(year.baseCents)),
                ),
                ListTile(
                  title: Text(year.complete ? l.netCosts : l.partialCosts),
                  subtitle: Text(money(year.netCents)),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l.billingRounding),
                ),
              ],
            ),
      ],
    );
  }
}
