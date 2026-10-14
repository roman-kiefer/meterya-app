import 'models.dart';

/// Amounts come from the API. Missing months and closing readings stay missing.
class MonthlyOverviewRow {
  final int month;
  final AnnualSummary? summary;
  final AnnualPosition? position;
  final Reading? closing;
  final Price? rate;
  final bool changingRate;
  const MonthlyOverviewRow(
    this.month,
    this.summary,
    this.position,
    this.closing,
    this.rate,
    this.changingRate,
  );
  bool get measured => position != null && position!.from.isNotEmpty;
  BigInt? get amount {
    if (!measured) return null;
    final parts = position!.quantity.split('.');
    return BigInt.parse(
      parts[0] + (parts.length == 1 ? '' : parts[1]).padRight(6, '0'),
    );
  }
}

class MonthlyOverviewModel {
  /// Month-end takes precedence over the following first day, as on the server.
  static List<MonthlyOverviewRow> rows(
    Point point,
    AnnualSummary? annual,
    Register register,
    int year,
  ) => [
    for (var month = 1; month <= 12; month++)
      _row(point, annual, register, year, month),
  ];

  static MonthlyOverviewRow _row(
    Point point,
    AnnualSummary? annual,
    Register register,
    int year,
    int month,
  ) {
    final summary = annual?.months
        .where((m) => m.month == month)
        .firstOrNull
        ?.summary;
    final position = summary?.positions
        .where((p) => p.registerId == register.id)
        .firstOrNull;
    final projected = summary?.overview
        .where((p) => p.registerId == register.id)
        .firstOrNull;
    return MonthlyOverviewRow(
      month,
      summary,
      position,
      projected?.closing,
      projected?.rate,
      projected?.changingRate ?? false,
    );
  }

  /// Only this bounded ratio is converted to floating point by the layout.
  static int heightUnits(MonthlyOverviewRow row, BigInt maximum) =>
      row.amount == null || maximum == BigInt.zero
      ? 0
      : ((row.amount! * BigInt.from(10000)) ~/ maximum).toInt().clamp(0, 10000);
}
