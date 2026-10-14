import 'models.dart';

class HeatPeriod {
  final String from, until, grid;
  final String? housePV, total;
  final bool valid;
  HeatPeriod.fromJson(Map<String, dynamic> j)
    : from = j['start_date'] as String,
      until = j['end_date'] as String,
      grid = j['grid_kwh'] as String,
      housePV = j['house_pv_kwh'] as String?,
      total = j['total_kwh'] as String?,
      valid = j['valid'] as bool,
      days = j['days'] as int? ?? 0;

  final int days;
}

class HeatReport {
  final List<Map<String, dynamic>> sources;
  String get currentNet =>
      sources
              .where((s) => s['role'] == 'NET' && s['valid_until'] == '')
              .lastOrNull?['point_id']
          as String? ??
      net;
  String get currentHouse =>
      sources
              .where((s) => s['role'] == 'HOUSE_PV' && s['valid_until'] == '')
              .lastOrNull?['point_id']
          as String? ??
      house;
  final String id, name, from, net, house;
  final List<String> flags;
  final List<HeatPeriod> gridPeriods, totalPeriods;
  final int version;
  final Tariffs tariffs;
  final List<AnnualSummary> annual;
  final List<Map<String, dynamic>> yearly;
  HeatReport.fromJson(Map<String, dynamic> j)
    : sources = (j['sources'] as List? ?? []).cast<Map<String, dynamic>>(),
      yearly = (j['yearly'] as List? ?? []).cast<Map<String, dynamic>>(),
      version = j['version'] as int? ?? 0,
      tariffs = Tariffs.fromJson(j['tariffs'] as Map<String, dynamic>? ?? {}),
      annual = (j['annual'] as List? ?? [])
          .map((v) => AnnualSummary.fromJson(v as Map<String, dynamic>))
          .toList(),
      id = j['id'] as String,
      name = j['name'] as String,
      from = j['valid_from'] as String,
      net = j['net_point'] as String,
      house = j['house_point'] as String,
      flags = (j['flags'] as List).cast<String>(),
      gridPeriods = (j['grid_periods'] as List)
          .map((v) => HeatPeriod.fromJson(v as Map<String, dynamic>))
          .toList(),
      totalPeriods = (j['total_periods'] as List)
          .map((v) => HeatPeriod.fromJson(v as Map<String, dynamic>))
          .toList();
  Point get billingPoint => Point(
    id,
    name,
    '',
    version,
    [Register(id, 'IMPORT', 'kWh')],
    const [],
    tariffs: tariffs,
    annual: annual,
  );
}

/// Totals and coverage are calculated by the API from valid periods.
class HeatPeriodTotals {
  final int days;
  final String? grid, housePV, total;
  HeatPeriodTotals.fromJson(Map<String, dynamic> j)
    : days = j['days'] as int? ?? 0,
      grid = j['grid_kwh'] as String?,
      housePV = j['house_pv_kwh'] as String?,
      total = j['total_kwh'] as String?;
}

class HeatYearOverview {
  final Map<String, dynamic> data;
  HeatYearOverview(HeatReport report, int year)
    : data = report.yearly.where((v) => v['year'] == year).firstOrNull ?? {};
  List<HeatPeriod> _periods(String field) => (data[field] as List? ?? [])
      .map((v) => HeatPeriod.fromJson(v as Map<String, dynamic>))
      .toList();
  List<HeatPeriod> get gridPeriods => _periods('grid_periods');
  List<HeatPeriod> get totalPeriods => _periods('total_periods');
  HeatPeriodTotals get gridTotals => HeatPeriodTotals.fromJson(
    data['grid_totals'] as Map<String, dynamic>? ?? {},
  );
  HeatPeriodTotals get totalTotals => HeatPeriodTotals.fromJson(
    data['total_totals'] as Map<String, dynamic>? ?? {},
  );
  String? get grid => gridTotals.grid;
  String? get housePV => totalTotals.housePV;
  String? get total => totalTotals.total;
  bool get sameCoverage => data['same_coverage'] as bool? ?? true;
  bool get hasGaps => data['has_gaps'] as bool? ?? false;
  String? get from => data['covered_from'] as String?;
  String? get until => data['covered_until'] as String?;
  int? get gridShare => data['grid_share_per_mille'] as int?;
  int? get pvShare => data['pv_share_per_mille'] as int?;
}
