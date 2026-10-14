import 'app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'heat_model.dart';
import 'l10n/app_localizations.dart';
import 'models.dart';
import 'tariff_view.dart';
import 'view_model.dart';

class HeatDetailsView extends StatelessWidget {
  final HeatReport report;
  final ViewModel model;
  final Future<void> Function() onTariffChanged;
  final bool busy;
  const HeatDetailsView({
    super.key,
    required this.report,
    required this.model,
    required this.onTariffChanged,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final source = model.points.where((p) => p.id == report.net).firstOrNull;
    final year = model.billingYear;
    final overview = HeatYearOverview(report, year);
    final prices = [...report.tariffs.basePrices, ...report.tariffs.unitPrices];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Panel(
          title: l.heatPeriodDetails,
          subtitle: l.heatPeriodsSubtitle,
          icon: Icons.table_chart_outlined,
          children: [
            _Notice(icon: Icons.info_outline, child: Text(l.heatHelp)),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final tables = [
                  HeatPeriodTable(
                    periods: overview.gridPeriods,
                    sums: overview.gridTotals,
                    total: false,
                  ),
                  HeatPeriodTable(
                    periods: overview.totalPeriods,
                    sums: overview.totalTotals,
                    total: true,
                  ),
                ];
                return constraints.maxWidth >= 740
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: tables[0]),
                          const SizedBox(width: 16),
                          Expanded(child: tables[1]),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          tables[0],
                          const SizedBox(height: 16),
                          tables[1],
                        ],
                      );
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        _Panel(
          title: l.heatCostDetails,
          subtitle: l.heatCostsSubtitle,
          icon: Icons.payments_outlined,
          children: [
            _Notice(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.heatTariffSource(source?.name ?? l.transitionDeleted),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(l.heatCostsHelp),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (prices.isEmpty)
              _Notice(
                icon: Icons.receipt_long_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.noTariffs,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(l.heatMissingPricesHelp),
                    if (source != null &&
                        !source.archived &&
                        model.workspace?.isAdmin == true) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: Text(l.heatSetSourceTariff),
                        onPressed: busy || model.busy
                            ? null
                            : () async {
                                await showDialog<void>(
                                  context: context,
                                  builder: (_) =>
                                      TariffDialog(model: model, point: source),
                                );
                                await onTariffChanged();
                              },
                      ),
                    ],
                  ],
                ),
              )
            else
              for (final price in prices) PriceTile(price: price, unit: 'kWh'),
            const SizedBox(height: 16),
            _AnnualCosts(report: report, year: year),
          ],
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final List<Widget> children;
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.of(context).border),
    ),
    child: ExpansionTile(
      initiallyExpanded: true,
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.of(context).panel,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 20, color: AppColors.of(context).heatAccent),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: children,
    ),
  );
}

class _Notice extends StatelessWidget {
  final Widget child;
  final IconData? icon;
  const _Notice({required this.child, this.icon});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.of(context).panel,
      borderRadius: BorderRadius.circular(8),
    ),
    child: DefaultTextStyle(
      style: Theme.of(context).textTheme.bodySmall!.copyWith(
        height: 1.6,
        color: AppColors.of(context).ink,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: AppColors.of(context).heatAccent),
            const SizedBox(width: 12),
          ],
          Expanded(child: child),
        ],
      ),
    ),
  );
}

class HeatPeriodTable extends StatelessWidget {
  final List<HeatPeriod> periods;
  final bool total;
  final HeatPeriodTotals sums;
  const HeatPeriodTable({
    super.key,
    required this.periods,
    required this.total,
    required this.sums,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = total
        ? AppColors.of(context).heatAccent
        : AppColors.of(context).grid;
    String quantity(String? value) =>
        value == null ? '—' : '${displayQuantity(value)} kWh';
    String date(String d) => DateFormat('dd.MM.yy').format(DateTime.parse(d));
    Widget cell(String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
      child: Text(
        value,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 11,
          fontWeight: strong ? FontWeight.w600 : null,
          color: strong ? color : null,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.of(context).panel.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            total ? l.heatCompositionTitle : l.heatGrid,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: color),
          ),
          const SizedBox(height: 6),
          if (periods.isEmpty)
            Text(l.noBillingReadings)
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: total ? 340 : 290),
                child: Table(
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  columnWidths: const {0: IntrinsicColumnWidth(flex: 1)},
                  children: [
                    TableRow(
                      children: [
                        cell(l.heatPeriod),
                        if (!total) cell(l.heatDays),
                        cell(total ? l.heatNetShort : l.heatGridShort),
                        if (total) ...[
                          cell(l.heatPVShort),
                          cell(l.heatTotalShort),
                        ],
                      ],
                    ),
                    for (final p in periods)
                      TableRow(
                        children: [
                          cell(
                            '${date(p.from)} – ${date(p.until)}${p.valid ? '' : ' · ${l.heatInvalid}'}',
                          ),
                          if (!total) cell('${p.days}'),
                          cell(quantity(p.grid)),
                          if (total) ...[
                            cell(quantity(p.housePV)),
                            cell(quantity(p.total)),
                          ],
                        ],
                      ),
                    TableRow(
                      decoration: BoxDecoration(
                        color: AppColors.of(context).table,
                      ),
                      children: [
                        cell(l.heatValidSum, strong: true),
                        if (!total) cell('${sums.days}', strong: true),
                        cell(quantity(sums.grid), strong: true),
                        if (total) ...[
                          cell(quantity(sums.housePV), strong: true),
                          cell(quantity(sums.total), strong: true),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnnualCosts extends StatelessWidget {
  final HeatReport report;
  final int year;
  const _AnnualCosts({required this.report, required this.year});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final summary = report.annual.where((s) => s.year == year).firstOrNull;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.of(context).panel,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          '$year · ${l.annualBilling}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        subtitle: summary == null
            ? null
            : Text(
                '${summary.complete ? l.completeYear : l.heatMeasuredCosts}${summary.estimated ? ' · ${l.estimatedAllocation}' : ''}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
        children: summary == null
            ? [ListTile(title: Text(l.noBillingReadings))]
            : [
                for (final warning in summary.warnings)
                  ListTile(
                    title: Text(switch (warning) {
                      'MEASUREMENT_GAP' => l.measurementGap,
                      'UNIT_PRICE_GAP' => l.unitPriceGap,
                      'BASE_PRICE_GAP' => l.basePriceGap,
                      _ => l.partialYear,
                    }),
                  ),
                for (final position in summary.positions)
                  ListTile(
                    dense: true,
                    title: Text(l.heatGrid),
                    subtitle: Text(
                      '${displayQuantity(position.quantity)} ${position.unit}',
                    ),
                    trailing: Text(
                      position.cents == null
                          ? l.notCalculated
                          : displayEuros(position.cents!),
                    ),
                  ),
                ListTile(
                  dense: true,
                  title: Text(l.baseCosts),
                  trailing: Text(
                    summary.baseCents == null
                        ? l.notCalculated
                        : displayEuros(summary.baseCents!),
                  ),
                ),
                ListTile(
                  dense: true,
                  title: Text(l.netCosts),
                  trailing: Text(
                    summary.netCents == null
                        ? l.notCalculated
                        : displayEuros(summary.netCents!),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l.billingRounding),
                ),
              ],
      ),
    );
  }
}
