import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'l10n/app_localizations.dart';
import 'models.dart';
import 'tariff_view.dart';

class CalculatedMonthlyView extends StatelessWidget {
  final AnnualSummary? summary;
  const CalculatedMonthlyView({super.key, required this.summary});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final format = DateFormat.yMd(
      Localizations.localeOf(context).toLanguageTag(),
    );
    String money(String? value) =>
        value == null ? l.notCalculated : displayEuros(value);
    return ExpansionTile(
      title: Text(l.calculatedMonthsTitle),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(l.calculatedMonthsHelp),
        ),
        if (summary == null || summary!.months.isEmpty)
          ListTile(title: Text(l.calculatedMonthsUnavailable))
        else
          for (final month in summary!.months)
            Builder(
              builder: (context) {
                final data = month.summary;
                final measured = data.positions.any((p) => p.from.isNotEmpty);
                return ExpansionTile(
                  title: Text(
                    DateFormat.MMMM(
                      l.localeName,
                    ).format(DateTime(data.year, month.month)),
                  ),
                  subtitle: Text(
                    measured
                        ? '${data.complete ? l.monthComplete : l.monthPartial}${data.estimated ? ' · ${l.estimatedAllocation}' : ''}\n${l.monthCosts}: ${money(data.netCents)}'
                        : l.monthNoData,
                  ),
                  children: [
                    for (final warning in data.warnings)
                      if (measured)
                        ListTile(
                          title: Text(switch (warning) {
                            'MEASUREMENT_GAP' => l.measurementGap,
                            'UNIT_PRICE_GAP' => l.unitPriceGap,
                            'BASE_PRICE_GAP' => l.basePriceGap,
                            _ => l.monthPartial,
                          }),
                        ),
                    for (final position in data.positions)
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
                              : '${l.readingPeriod(format.format(DateTime.parse(position.from)), format.format(DateTime.parse(position.until)))}\n${money(position.cents)}',
                        ),
                      ),
                    if (measured)
                      ListTile(
                        title: Text(l.baseCosts),
                        subtitle: Text(money(data.baseCents)),
                      ),
                  ],
                );
              },
            ),
      ],
    );
  }
}
