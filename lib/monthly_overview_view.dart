import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'l10n/app_localizations.dart';
import 'main.dart';
import 'models.dart';
import 'monthly_overview_model.dart';
import 'register_tabs.dart';

/// Monthly chart and billing table from the server's calculated read model.
class MonthlyOverviewView extends StatefulWidget {
  final AnnualSummary? summary;
  final Point point;
  final int year;
  const MonthlyOverviewView({
    super.key,
    required this.summary,
    required this.point,
    required this.year,
  });

  @override
  State<MonthlyOverviewView> createState() => _MonthlyOverviewViewState();
}

class _MonthlyOverviewViewState extends State<MonthlyOverviewView> {
  String? selectedRegisterId;
  Point get point => widget.point;
  AnnualSummary? get summary => widget.summary;
  int get year => widget.year;

  @override
  void didUpdateWidget(covariant MonthlyOverviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.point.id != point.id) selectedRegisterId = null;
  }

  String _money(String? value) => value == null
      ? '—'
      : displayEuros(value, locale: AppLocalizations.of(context).localeName);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final baseRegister = point.registers
        .where((r) => r.direction != 'EXPORT')
        .firstOrNull
        ?.id;
    final register =
        point.registers.where((r) => r.id == selectedRegisterId).firstOrNull ??
        point.registers.firstOrNull;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${l.monthlyOverviewTitle} $year',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          point.isVirtual ? l.virtualHelp : l.monthlyOverviewHelp,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (point.registers.length > 1) ...[
          const SizedBox(height: 12),
          RegisterTabs(
            registers: point.registers,
            selectedId: register!.id,
            onChanged: (id) => setState(() => selectedRegisterId = id),
          ),
        ],
        if (summary == null || summary!.months.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(l.calculatedMonthsUnavailable),
          )
        else ...[
          if (register != null)
            _register(context, register, register.id == baseRegister),
          if (!point.isVirtualHeat || register?.id == baseRegister)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '${point.isVirtualHeat ? l.virtualGridCosts : l.monthCosts}: ${_money(summary!.netCents)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
        ],
      ],
    );
    return content;
  }

  Widget _register(BuildContext context, Register register, bool showBase) {
    final l = AppLocalizations.of(context);
    final export = register.direction == 'EXPORT';
    final showMoney = !point.isVirtualHeat || showBase;
    final color = registerAccent(register.direction, context);
    final pale = export
        ? AppColors.of(context).exportPanel
        : AppColors.of(context).table;
    final rows = MonthlyOverviewModel.rows(point, summary, register, year);
    final maximum = rows.fold(
      BigInt.zero,
      (max, row) => row.amount != null && row.amount! > max ? row.amount! : max,
    );
    final total = summary!.positions
        .where((p) => p.registerId == register.id)
        .firstOrNull;
    String quantity(AnnualPosition? p) => p == null || p.from.isEmpty
        ? '—'
        : '${displayQuantity(p.quantity, locale: l.localeName)} ${register.unit}';
    String rate(MonthlyOverviewRow row) => row.changingRate
        ? l.monthRateChanges
        : row.rate == null
        ? '—'
        : '${displayQuantity('${row.rate!.cents ~/ 1000}.${(row.rate!.cents % 1000).toString().padLeft(3, '0')}', locale: l.localeName)} ct/${register.unit}';
    String totalMoney(AnnualSummary? value) => _money(
      value?.overview
          .where((v) => v.registerId == register.id)
          .firstOrNull
          ?.totalCents,
    );
    final headers = [
      l.statementMonth,
      if (!point.isVirtual) l.statementReading,
      export ? l.exportRegister : l.statementConsumption,
      if (!point.isVirtual) export ? l.statementExportRate : l.statementRate,
      if (showMoney)
        point.isVirtualHeat
            ? l.virtualGridEnergy
            : export
            ? l.statementExportEnergy
            : l.statementEnergy,
      if (showBase) l.baseCosts,
      if (showMoney)
        point.isVirtualHeat
            ? l.virtualGridCosts
            : export
            ? l.statementExportTotal
            : l.statementTotal,
    ];
    return Card(
      margin: const EdgeInsets.only(top: 20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 24,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text(
                  registerName(l, register),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (rows.any((row) => !row.measured))
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.square, size: 12, color: pale),
                      const SizedBox(width: 8),
                      Text(l.monthOpen),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: constraints.maxWidth < 550
                      ? 550
                      : constraints.maxWidth,
                  height: 170,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final row in rows)
                        Expanded(
                          child: Tooltip(
                            message:
                                '${DateFormat.MMMM(l.localeName).format(DateTime(year, row.month))}: ${row.measured ? quantity(row.position) : l.monthOpen}${row.position?.estimated == true ? ' · ${l.estimatedAllocation}' : ''}',
                            child: Semantics(
                              label:
                                  '${DateFormat.MMMM(l.localeName).format(DateTime(year, row.month))}: ${row.measured ? quantity(row.position) : l.monthOpen}',
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      key: ValueKey(
                                        'month-bar-${register.id}-${row.month}',
                                      ),
                                      height: row.measured
                                          ? 2 +
                                                120 *
                                                    MonthlyOverviewModel.heightUnits(
                                                      row,
                                                      maximum,
                                                    ) /
                                                    10000
                                          : 12,
                                      decoration: BoxDecoration(
                                        color: row.measured ? color : pale,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(3),
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      DateFormat.MMM(
                                        l.localeName,
                                      ).format(DateTime(year, row.month)),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  columnSpacing: 24,
                  horizontalMargin: 20,
                  headingRowColor: WidgetStatePropertyAll(pale),
                  dataRowMinHeight: 60,
                  dataRowMaxHeight: 80,
                  columns: [
                    for (var i = 0; i < headers.length; i++)
                      DataColumn(numeric: i > 0, label: Text(headers[i])),
                  ],
                  rows: [
                    for (final row in rows)
                      DataRow(
                        color: row.measured
                            ? null
                            : WidgetStatePropertyAll(
                                pale.withValues(alpha: .35),
                              ),
                        cells: [
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat.MMMM(
                                    l.localeName,
                                  ).format(DateTime(year, row.month)),
                                ),
                                if (row.position?.estimated == true)
                                  Text(
                                    l.estimatedAllocation,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  )
                                else if (row.measured &&
                                    row.position?.complete == false)
                                  Text(
                                    l.monthPartial,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                              ],
                            ),
                          ),
                          if (!point.isVirtual)
                            DataCell(
                              Text(
                                row.closing == null
                                    ? '—'
                                    : '${displayQuantity(row.closing!.value, locale: l.localeName)} ${register.unit}',
                              ),
                            ),
                          DataCell(
                            Text(
                              row.measured
                                  ? quantity(row.position)
                                  : l.monthOpen,
                            ),
                          ),
                          if (!point.isVirtual) DataCell(Text(rate(row))),
                          if (showMoney)
                            DataCell(
                              Text(
                                row.measured
                                    ? _money(row.position!.cents)
                                    : '—',
                              ),
                            ),
                          if (showBase)
                            DataCell(
                              Text(
                                row.measured
                                    ? _money(row.summary?.baseCents)
                                    : '—',
                              ),
                            ),
                          if (showMoney)
                            DataCell(
                              Text(
                                row.measured ? totalMoney(row.summary) : '—',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    DataRow(
                      color: WidgetStatePropertyAll(pale),
                      cells: [
                        DataCell(
                          Text(
                            l.monthSubtotal,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (!point.isVirtual) const DataCell(Text('—')),
                        DataCell(Text(quantity(total))),
                        if (!point.isVirtual) const DataCell(Text('—')),
                        if (showMoney) DataCell(Text(_money(total?.cents))),
                        if (showBase)
                          DataCell(Text(_money(summary!.baseCents))),
                        if (showMoney)
                          DataCell(
                            Text(
                              totalMoney(summary),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
