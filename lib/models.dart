import 'photo_model.dart';

class Workspace {
  final String id, name, role;
  final int version;
  const Workspace(this.id, this.name, this.role, {this.version = 1});
  factory Workspace.fromJson(Map<String, dynamic> j) => Workspace(
    j['id'] as String,
    j['name'] as String,
    j['role'] as String,
    version: j['version'] as int? ?? 1,
  );
  bool get isAdmin => role == 'ADMIN' || role == 'MODERATOR';
  bool get isSystemAdmin => role == 'ADMIN';
  bool get canRecord => isAdmin || role == 'USER';
}

class WorkspaceMember {
  final String subject, email, role;
  final bool systemAdmin, active;
  const WorkspaceMember(
    this.subject,
    this.email,
    this.role, {
    this.systemAdmin = false,
    this.active = true,
  });
  factory WorkspaceMember.fromJson(Map<String, dynamic> j) => WorkspaceMember(
    j['subject'] as String,
    j['email'] as String,
    j['role'] as String,
    systemAdmin: j['system_admin'] == true,
    active: j['active'] != false,
  );
}

class Memberships {
  final int version;
  final List<WorkspaceMember> members;
  const Memberships(this.version, this.members);
  factory Memberships.fromJson(Map<String, dynamic> j) => Memberships(
    j['version'] as int,
    (j['members'] as List)
        .map((m) => WorkspaceMember.fromJson(m as Map<String, dynamic>))
        .toList(),
  );
}

class Invitation {
  final String id, email, role, status;
  final int version;
  final DateTime expires;
  const Invitation(
    this.id,
    this.email,
    this.role,
    this.status,
    this.version,
    this.expires,
  );
  factory Invitation.fromJson(Map<String, dynamic> j) => Invitation(
    j['id'] as String,
    j['email'] as String,
    j['role'] as String,
    j['status'] as String,
    j['version'] as int,
    DateTime.parse(j['expires_at'] as String),
  );
}

class Register {
  final String id, direction, unit;
  const Register(this.id, this.direction, this.unit);
  factory Register.fromJson(Map<String, dynamic> j) => Register(
    j['id'] as String,
    j['direction'] as String,
    j['unit'] as String,
  );
}

class Reading {
  final String date, value, registerId;
  final String? id, actor, difference;
  final bool boundaryPriority;
  const Reading(
    this.date,
    this.value,
    this.registerId, {
    this.id,
    this.actor,
    this.difference,
    this.boundaryPriority = false,
  });
  factory Reading.fromJson(Map<String, dynamic> j) => Reading(
    j['date'] as String,
    j['value'] as String,
    j['register_id'] as String,
    id: j['id'] as String?,
    actor: j['actor'] as String?,
    difference: j['difference_quantity'] as String?,
    boundaryPriority: j['boundary_priority'] as bool? ?? false,
  );
}

class Point {
  final List<ReadingPhoto> photos;
  final String id, name, serial;
  final String kind;
  final Map<String, dynamic>? virtualInfo;
  bool get isVirtual => kind == 'VIRTUAL';
  bool get isVirtualHeat => virtualInfo?['definition']?['type'] == 'HEAT';
  String? get dataVersion => virtualInfo?['data_version'] as String?;
  List<Map<String, dynamic>> get virtualSources =>
      (virtualInfo?['sources'] as List? ?? []).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get virtualPeriods =>
      (virtualInfo?['periods'] as List? ?? []).cast<Map<String, dynamic>>();
  List<String> get virtualFlags =>
      (virtualInfo?['flags'] as List? ?? []).cast<String>();
  final int version;
  final List<Register> registers;
  final bool archived;
  final List<Reading> readings;
  final List<ConsumptionInterval>? consumption;
  final Tariffs tariffs;
  final List<AnnualSummary>? annual;
  final List<MonthlyBill> monthlyBilling;
  final List<Map<String, dynamic>> history;
  Point(
    this.id,
    this.name,
    this.serial,
    this.version,
    Iterable<Register> registers,
    Iterable<Reading> readings, {
    this.archived = false,
    this.kind = 'PHYSICAL',
    this.virtualInfo,
    this.photos = const [],
    this.history = const [],
    Iterable<ConsumptionInterval>? consumption,
    Tariffs? tariffs,
    Iterable<AnnualSummary>? annual,
    Iterable<MonthlyBill> monthlyBilling = const [],
  }) : registers = List.unmodifiable(registers),
       readings = List.unmodifiable(readings),
       consumption = consumption == null
           ? null
           : List.unmodifiable(consumption),
       tariffs = tariffs ?? const Tariffs([], []),
       annual = annual == null ? null : List.unmodifiable(annual),
       monthlyBilling = List.unmodifiable(monthlyBilling);
  factory Point.fromJson(Map<String, dynamic> j) {
    final meter = j['meter'] as Map<String, dynamic>;
    final readings =
        (j['readings'] as List)
            .map((r) => Reading.fromJson(r as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return Point(
      j['id'] as String,
      j['name'] as String,
      meter['serial'] as String,
      j['version'] as int,
      (meter['registers'] as List).map(
        (r) => Register.fromJson(r as Map<String, dynamic>),
      ),
      readings,
      kind: j['kind'] as String? ?? 'PHYSICAL',
      virtualInfo: j['virtual'] as Map<String, dynamic>?,
      photos: (j['photos'] as List? ?? [])
          .map((p) => ReadingPhoto.fromJson(p as Map<String, dynamic>))
          .toList(),
      history: (j['history'] as List? ?? []).cast<Map<String, dynamic>>(),
      archived: j['archived'] as bool? ?? false,
      consumption: (j['consumption'] as List?)?.map(
        (interval) =>
            ConsumptionInterval.fromJson(interval as Map<String, dynamic>),
      ),
      tariffs: Tariffs.fromJson(j['tariffs'] as Map<String, dynamic>? ?? {}),
      annual: (j['annual'] as List?)?.map(
        (s) => AnnualSummary.fromJson(s as Map<String, dynamic>),
      ),
      monthlyBilling: (j['monthly_billing'] as List? ?? []).map(
        (b) => MonthlyBill.fromJson(b as Map<String, dynamic>),
      ),
    );
  }
}

class MonthlyBill {
  final int year;
  final String registerId, direction;
  bool get isExport => direction == 'EXPORT';
  final bool complete;
  final String opening, quantity, energy, base, payment, total, balance;
  final List<MonthlyBillRow> rows;
  MonthlyBill.fromJson(Map<String, dynamic> j)
    : year = j['year'] as int,
      registerId = j['register_id'] as String? ?? '',
      direction = j['direction'] as String? ?? 'IMPORT',
      complete = j['complete'] as bool,
      opening = j['opening_value'] as String,
      quantity = j['quantity'] as String,
      energy = j['energy_cents'] as String,
      base = j['base_cents'] as String,
      payment = j['payment_cents'] as String,
      total = j['total_cents'] as String,
      balance = j['balance_cents'] as String,
      rows = (j['rows'] as List)
          .map((r) => MonthlyBillRow.fromJson(r as Map<String, dynamic>))
          .toList();
}

class MonthlyBillRow {
  final String date, value, quantity, energy;
  final int rate, base, payment;
  MonthlyBillRow.fromJson(Map<String, dynamic> j)
    : date = j['date'] as String,
      value = j['value'] as String,
      quantity = j['quantity'] as String,
      energy = j['energy_euros_exact'] as String,
      rate = j['unit_cents_per_1000'] as int,
      base = j['base_cents'] as int,
      payment = j['payment_cents'] as int;
}

class ConsumptionInterval {
  final String registerId, startDate, endDate, quantity, unit;
  const ConsumptionInterval(
    this.registerId,
    this.startDate,
    this.endDate,
    this.quantity,
    this.unit,
  );
  factory ConsumptionInterval.fromJson(Map<String, dynamic> j) =>
      ConsumptionInterval(
        j['register_id'] as String,
        j['start_date'] as String,
        j['end_date'] as String,
        j['quantity'] as String,
        j['unit'] as String,
      );
}

String decimalSeparator(String locale) => locale.startsWith('en') ? '.' : ',';

String displayQuantity(String value, {String locale = 'de'}) {
  final parts = value.split('.');
  if (parts.length == 1) return value;
  final fraction = parts[1].replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty
      ? parts[0]
      : '${parts[0]}${decimalSeparator(locale)}$fraction';
}

String? normalizeReading(String input) {
  final value = input.trim().replaceAll(',', '.');
  return RegExp(r'^(0|[1-9][0-9]{0,13})(\.[0-9]{1,6})?$').hasMatch(value)
      ? value
      : null;
}

bool validDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
  final date = DateTime.tryParse(value);
  return date != null && date.toIso8601String().startsWith(value);
}

class Price {
  final String from, until, category, period;
  final int cents;
  const Price(this.from, this.until, this.cents, this.category, this.period);
  factory Price.fromJson(Map<String, dynamic> j, {bool base = false}) => Price(
    j['valid_from'] as String,
    j['valid_until'] as String? ?? '',
    j['cents'] as int,
    base ? 'BASE' : j['direction'] as String,
    base ? j['period'] as String : '',
  );
  Map<String, dynamic> toJson() => {
    'valid_from': from,
    'valid_until': until,
    'cents': cents,
    if (category == 'BASE') 'period': period else 'direction': category,
  };
}

class Tariffs {
  final List<Price> basePrices, unitPrices;
  const Tariffs(this.basePrices, this.unitPrices);
  factory Tariffs.fromJson(Map<String, dynamic> j) => Tariffs(
    List.unmodifiable(
      (j['base_prices'] as List? ?? []).map(
        (p) => Price.fromJson(p as Map<String, dynamic>, base: true),
      ),
    ),
    List.unmodifiable(
      (j['unit_prices'] as List? ?? []).map(
        (p) => Price.fromJson(p as Map<String, dynamic>),
      ),
    ),
  );
  Map<String, dynamic> toJson() => {
    'base_prices': basePrices.map((p) => p.toJson()).toList(),
    'unit_prices': unitPrices.map((p) => p.toJson()).toList(),
  };
}

class AnnualPosition {
  final String registerId, direction, unit, quantity, from, until;
  final String? cents;
  final bool estimated, complete;
  final bool hasGaps;
  const AnnualPosition(
    this.registerId,
    this.direction,
    this.unit,
    this.quantity,
    this.from,
    this.until,
    this.cents,
    this.estimated,
    this.complete, {
    this.hasGaps = false,
  });
  factory AnnualPosition.fromJson(Map<String, dynamic> j) => AnnualPosition(
    j['register_id'] as String,
    j['direction'] as String,
    j['unit'] as String,
    j['quantity'] as String,
    j['covered_from'] as String,
    j['covered_until'] as String,
    j['cents'] as String?,
    j['estimated'] as bool,
    j['complete'] as bool,
    hasGaps: j['has_gaps'] as bool? ?? false,
  );
}

class CalculatedMonth {
  final int month;
  final AnnualSummary summary;
  const CalculatedMonth(this.month, this.summary);
  factory CalculatedMonth.fromJson(Map<String, dynamic> j) =>
      CalculatedMonth(j['month'] as int, AnnualSummary.fromJson(j));
}

class RegisterOverview {
  final String registerId;
  final String? totalCents;
  final Reading? closing;
  final Price? rate;
  final bool changingRate;
  RegisterOverview.fromJson(Map<String, dynamic> j)
    : registerId = j['register_id'] as String,
      totalCents = j['total_cents'] as String?,
      closing = j['closing'] == null
          ? null
          : Reading.fromJson(j['closing'] as Map<String, dynamic>),
      rate = j['rate'] == null
          ? null
          : Price.fromJson(j['rate'] as Map<String, dynamic>),
      changingRate = j['changing_rate'] as bool? ?? false;
}

class AnnualSummary {
  final int year;
  final int? pointVersion, calculationVersion;
  final List<CalculatedMonth> months;
  final List<RegisterOverview> overview;
  final bool complete, estimated;
  final String? baseCents, netCents;
  final List<String> warnings;
  final List<AnnualPosition> positions;
  const AnnualSummary(
    this.year,
    this.complete,
    this.estimated,
    this.baseCents,
    this.netCents,
    this.warnings,
    this.positions, {
    this.pointVersion,
    this.calculationVersion,
    this.months = const [],
    this.overview = const [],
  });
  factory AnnualSummary.fromJson(Map<String, dynamic> j) => AnnualSummary(
    j['year'] as int,
    j['complete'] as bool,
    j['estimated'] as bool,
    j['base_cents'] as String?,
    j['net_cents'] as String?,
    List<String>.from(j['warnings'] as List),
    List.unmodifiable(
      (j['positions'] as List).map(
        (p) => AnnualPosition.fromJson(p as Map<String, dynamic>),
      ),
    ),
    overview: (j['overview'] as List? ?? [])
        .map((v) => RegisterOverview.fromJson(v as Map<String, dynamic>))
        .toList(),
    pointVersion: j['point_version'] as int?,
    calculationVersion: j['calculation_version'] as int?,
    months: List.unmodifiable(
      (j['months'] as List? ?? []).map(
        (m) => CalculatedMonth.fromJson(m as Map<String, dynamic>),
      ),
    ),
  );
}

// Exact euro input: base prices in cents; unit prices in cents per 1,000 units.
int? parsePrice(String input, {required bool base}) {
  final value = input.trim().replaceAll(',', '.');
  final places = base ? 2 : 5;
  if (!RegExp(
    '^(0|[1-9][0-9]{0,10})(\\.[0-9]{1,$places})?\$',
  ).hasMatch(value)) {
    return null;
  }
  final parts = value.split('.');
  final digits =
      parts[0] + (parts.length == 2 ? parts[1] : '').padRight(places, '0');
  final amount = BigInt.parse(digits);
  return amount > BigInt.from(1000000000000) ? null : amount.toInt();
}

String displayEuros(String cents, {String locale = 'de'}) {
  final negative = cents.startsWith('-');
  final digits = (negative ? cents.substring(1) : cents).padLeft(3, '0');
  return '${negative ? '−' : ''}${digits.substring(0, digits.length - 2)}${decimalSeparator(locale)}${digits.substring(digits.length - 2)} €';
}

String displayUnitPrice(int cents, {String locale = 'de'}) {
  final digits = cents.toString().padLeft(6, '0');
  return displayQuantity(
    '${digits.substring(0, digits.length - 5)}.${digits.substring(digits.length - 5)}',
    locale: locale,
  );
}
