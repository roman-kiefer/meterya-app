import 'models.dart';

/// API-projected accounting values; only chart normalization and formatting
/// happen locally. An absent projection is unavailable, never recomputed.
Map<String, dynamic> historyWindow(Point p, String id, int year) =>
    p.history
        .where((w) => w['register_id'] == id && w['until_year'] == year)
        .firstOrNull ??
    {};
String? formatPercent(String? value) =>
    value == null ? null : '${value.replaceAll('.', ',')} %';

class YearBar {
  final int year;
  final AnnualPosition? position;
  final BigInt? amount;
  final int widthUnits;
  final String? costCents;
  final bool completeYear;
  final YearOnYearComparison? change;
  const YearBar(
    this.year,
    this.position,
    this.amount,
    this.widthUnits, {
    this.costCents,
    this.completeYear = false,
    this.change,
  });
}

class YearComparisonModel {
  /// Round displayed quantities to two decimal places using integer arithmetic.
  static String formatQuantity(String value, {String locale = 'de'}) {
    final amount = quantityAmount(value);
    if (amount == null) return '—';
    final digits = ((amount + BigInt.from(5000)) ~/ BigInt.from(10000))
        .toString()
        .padLeft(3, '0');
    return '${digits.substring(0, digits.length - 2)}${decimalSeparator(locale)}${digits.substring(digits.length - 2)}';
  }

  static List<YearBar> window(Point point, String registerId, int lastYear) {
    final data = historyWindow(point, registerId, lastYear);
    final raw = (data['rows'] as List? ?? []);
    final rows = <YearBar>[];
    for (var y = lastYear - 4; y <= lastYear; y++) {
      final j =
          raw
              .cast<Map<String, dynamic>>()
              .where((r) => r['year'] == y)
              .firstOrNull ??
          {};
      final pos = j['position'] == null
          ? null
          : AnnualPosition.fromJson(j['position'] as Map<String, dynamic>);
      rows.add(
        YearBar(
          y,
          pos,
          pos == null ? null : quantityAmount(pos.quantity),
          0,
          costCents: j['cost_cents'] as String?,
          completeYear: j['complete_year'] as bool? ?? false,
          change: j['change'] == null
              ? null
              : YearOnYearComparison.fromJson(
                  j['change'] as Map<String, dynamic>,
                ),
        ),
      );
    }
    final maximum = rows.fold(
      BigInt.zero,
      (v, r) => r.amount != null && r.amount! > v ? r.amount! : v,
    );
    return rows
        .map(
          (r) => YearBar(
            r.year,
            r.position,
            r.amount,
            r.amount == null || maximum == BigInt.zero
                ? 0
                : ((r.amount! * BigInt.from(10000)) ~/ maximum).toInt().clamp(
                    0,
                    10000,
                  ),
            costCents: r.costCents,
            completeYear: r.completeYear,
            change: r.change,
          ),
        )
        .toList();
  }

  static BigInt? quantityAmount(String value) {
    if (!RegExp(r'^\d+(\.\d{1,6})?$').hasMatch(value)) return null;
    final parts = value.split('.');
    return BigInt.parse(
      parts[0] + (parts.length == 1 ? '' : parts[1]).padRight(6, '0'),
    );
  }
}

class YearHistoryStatistics {
  final String? quantityMean, costMean;
  YearHistoryStatistics(Point point, String id, int year)
    : quantityMean = historyWindow(point, id, year)['quantity_mean'] as String?,
      costMean = historyWindow(point, id, year)['cost_mean_cents'] as String?;
}

class YearOnYearComparison {
  final String? percent;
  final List<int> months;
  final bool estimated;
  YearOnYearComparison.fromJson(Map<String, dynamic> j)
    : percent = formatPercent(j['percent'] as String?),
      months = (j['months'] as List? ?? []).cast<int>(),
      estimated = j['estimated'] as bool? ?? false;
  static YearOnYearComparison? forYear(Point p, String id, int year) =>
      YearComparisonModel.window(p, id, year).last.change;
}

class HistoryTrend {
  final int fromYear, untilYear, count, direction;
  final String? percent;
  HistoryTrend.window(Point p, String id, int year)
    : fromYear = year - 4,
      untilYear = year,
      count = historyWindow(p, id, year)['trend_count'] as int? ?? 0,
      direction = historyWindow(p, id, year)['trend_direction'] as int? ?? 0,
      percent = formatPercent(
        historyWindow(p, id, year)['trend_percent'] as String?,
      );
}
