import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'l10n/app_localizations.dart';
import 'models.dart';
import 'register_tabs.dart';
import 'year_comparison_model.dart';
import 'year_trend_barometer.dart';

/// Compact register history with averages for the displayed periods.
class YearComparisonView extends StatefulWidget {
  final Point point;
  final int lastYear;
  const YearComparisonView({
    super.key,
    required this.point,
    required this.lastYear,
  });
  @override
  State<YearComparisonView> createState() => _YearComparisonViewState();
}

class _YearComparisonViewState extends State<YearComparisonView> {
  String? selectedRegister;
  @override
  void didUpdateWidget(covariant YearComparisonView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.point.id != widget.point.id) selectedRegister = null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final register =
        widget.point.registers
            .where((r) => r.id == selectedRegister)
            .firstOrNull ??
        widget.point.registers.firstOrNull;
    if (register == null) return Text(l.noReadings);
    final rows = YearComparisonModel.window(
      widget.point,
      register.id,
      widget.lastYear,
    );
    final stats = YearHistoryStatistics(
      widget.point,
      register.id,
      widget.lastYear,
    );
    final color = registerAccent(register.direction, context);
    final pale = register.direction == 'EXPORT'
        ? AppColors.of(context).exportPanel
        : AppColors.of(context).table;
    final format = (l.localeName == 'de'
        ? DateFormat('dd.MM.', l.localeName)
        : DateFormat.Md(l.localeName));
    Widget metric(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            Text(l.yearsTab, style: Theme.of(context).textTheme.titleLarge),
            Text(
              '${widget.lastYear - 4} – ${widget.lastYear}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(l.yearsHelp, style: Theme.of(context).textTheme.bodySmall),
        if (widget.point.registers.length > 1) ...[
          const SizedBox(height: 12),
          RegisterTabs(
            registers: widget.point.registers,
            selectedId: register.id,
            onChanged: (id) => setState(() => selectedRegister = id),
          ),
        ],
        Card(
          margin: const EdgeInsets.only(top: 20, bottom: 24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Tooltip(
                  message: l.historyAvailableMeanHelp,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: pale,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final quantity = metric(
                          l.historyMeanQuantityLabel,
                          stats.quantityMean == null
                              ? '—'
                              : '${YearComparisonModel.formatQuantity(stats.quantityMean!, locale: l.localeName)} ${register.unit}',
                        );
                        final cost = metric(
                          widget.point.isVirtualHeat
                              ? l.virtualCostMean
                              : l.historyMeanCostLabel,
                          stats.costMean == null
                              ? '—'
                              : displayEuros(
                                  stats.costMean!,
                                  locale: l.localeName,
                                ),
                        );
                        final trend = YearTrendBarometer(
                          trend: HistoryTrend.window(
                            widget.point,
                            register.id,
                            widget.lastYear,
                          ),
                          color: color,
                        );
                        return constraints.maxWidth < 550
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  quantity,
                                  const SizedBox(height: 16),
                                  cost,
                                  const SizedBox(height: 16),
                                  trend,
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: quantity),
                                  const SizedBox(width: 24),
                                  Expanded(child: cost),
                                  const SizedBox(width: 24),
                                  Expanded(child: trend),
                                ],
                              );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                for (final row in rows.reversed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 16,
                          runSpacing: 4,
                          children: [
                            Text(
                              row.amount == null
                                  ? '${row.year} · ${l.comparisonMissing}'
                                  : row.completeYear
                                  ? '${row.year}'
                                  : l.historyYearPeriod(
                                      row.year,
                                      format.format(
                                        DateTime.parse(row.position!.from),
                                      ),
                                      format.format(
                                        DateTime.parse(row.position!.until),
                                      ),
                                    ),
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            if (row.amount != null)
                              _yearValues(context, register, row),
                          ],
                        ),
                        if (row.amount != null) ...[
                          const SizedBox(height: 8),
                          Semantics(
                            label: l.comparisonBar(
                              row.year.toString(),
                              YearComparisonModel.formatQuantity(
                                row.position!.quantity,
                                locale: l.localeName,
                              ),
                              register.unit,
                            ),
                            child: ExcludeSemantics(
                              child: LinearProgressIndicator(
                                key: ValueKey('bar-${register.id}-${row.year}'),
                                value: row.widthUnits / 10000,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(8),
                                color: row.year == widget.lastYear
                                    ? color
                                    : color.withValues(alpha: .75),
                                backgroundColor: pale,
                              ),
                            ),
                          ),
                          if (row.position!.estimated)
                            Text(
                              l.estimatedAllocation,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _yearValues(BuildContext context, Register register, YearBar row) {
    final l = AppLocalizations.of(context);
    final year = row.year;
    final comparison = YearOnYearComparison.forYear(
      widget.point,
      register.id,
      year,
    );
    final percent = l.localeName.startsWith('en')
        ? comparison?.percent?.replaceAll(',', '.')
        : comparison?.percent;
    final months = comparison?.months ?? const <int>[];
    final monthFormat = DateFormat.MMM(
      Localizations.localeOf(context).toLanguageTag(),
    );
    String month(int value) => monthFormat.format(DateTime(year, value));
    final period = months.isEmpty
        ? ''
        : months.length == 1
        ? month(months.single)
        : months.last - months.first + 1 == months.length
        ? '${month(months.first)}–${month(months.last)}'
        : months.map(month).join(', ');
    final label = percent == null
        ? l.historyPreviousUnavailable
        : months.isEmpty
        ? l.historyTrend(percent, year - 1)
        : l.historyMonthComparison(percent, year - 1, period);
    return Tooltip(
      message:
          '$label${percent != null && comparison!.estimated ? ' · ${l.estimatedAllocation}' : ''}',
      child: Text(
        '${YearComparisonModel.formatQuantity(row.position!.quantity, locale: l.localeName)} ${register.unit} | ${row.costCents == null ? '—' : displayEuros(row.costCents!, locale: l.localeName)} | ${percent ?? '—'}',
        key: ValueKey('year-values-${register.id}-$year'),
        style: TextStyle(
          color: registerAccent(register.direction, context),
          fontWeight: year == widget.lastYear
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    );
  }
}
