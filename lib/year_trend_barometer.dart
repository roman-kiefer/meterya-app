import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'year_comparison_model.dart';

/// Compact direction indicator for the mean trend over the displayed years.
class YearTrendBarometer extends StatelessWidget {
  final HistoryTrend trend;
  final Color color;
  const YearTrendBarometer({
    super.key,
    required this.trend,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final percent = trend.percent;
    final delta = percent == null ? null : trend.direction;
    final direction = delta == null
        ? l.historyPreviousUnavailable
        : delta == 0
        ? l.historyTrendFlat
        : delta < 0
        ? l.historyTrendDown
        : l.historyTrendUp;
    final icon = delta == 0
        ? Icons.trending_flat
        : (delta ?? 0) < 0
        ? Icons.trending_down
        : Icons.trending_up;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.historyMeanTrendLabel,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        Tooltip(
          message: percent == null
              ? l.historyPreviousUnavailable
              : '${l.historyWindowTrendHelp(trend.fromYear, trend.untilYear, trend.count)} · $direction',
          child: Row(
            children: [
              if (percent != null) ...[
                Icon(
                  icon,
                  key: const ValueKey('trend-direction'),
                  color: color,
                  size: 24,
                  semanticLabel: direction,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  percent ?? '—',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
