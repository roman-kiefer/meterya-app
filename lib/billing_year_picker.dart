import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';

/// Compact year navigation, ordered from newest to oldest available year.
class BillingYearPicker extends StatelessWidget {
  final List<int> years;
  final int year;
  final bool busy;
  final ValueChanged<int> onChanged;
  final String keyPrefix;

  const BillingYearPicker({
    super.key,
    required this.years,
    required this.year,
    required this.onChanged,
    this.busy = false,
    this.keyPrefix = 'billing-year',
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final index = years.indexOf(year);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l.previousBillingYear,
          onPressed: !busy && index >= 0 && index < years.length - 1
              ? () => onChanged(years[index + 1])
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Semantics(
          label: l.costYear,
          value: '$year',
          child: Text(
            '$year',
            key: ValueKey('$keyPrefix-$year'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        IconButton(
          tooltip: l.nextBillingYear,
          onPressed: !busy && index > 0
              ? () => onChanged(years[index - 1])
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
