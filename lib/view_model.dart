import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'models.dart';
import 'repository.dart';
import 'transition_model.dart';
import 'meter_selection_store.dart';

class ViewModel extends ChangeNotifier {
  final Repository repository;
  String? apiVersion;
  bool versionLoading = true;
  Future<void>? _versionRequest;
  bool _disposed = false;

  /// Fetch once per app instance, independently of session and workspace state.
  Future<void> loadVersion() => _versionRequest ??= _loadVersion();

  Future<void> _loadVersion() async {
    String? version;
    try {
      version = await repository.version();
    } catch (_) {
      // Optional diagnostics must never interrupt authentication or normal use.
    }
    if (_disposed) return;
    apiVersion = version;
    versionLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<Workspace> workspaces = [];
  List<Point> points = [];
  List<MeterTransition> meterTransitions = [];
  Workspace? workspace;
  bool hasHeatConfiguration = false;
  String? error;
  bool busy = false, signedIn = false;
  final MeterSelectionStore meterSelections;
  ViewModel(this.repository, {MeterSelectionStore? meterSelections})
    : meterSelections = meterSelections ?? MeterSelectionStore();
  String? get _meterScope => workspace == null
      ? null
      : 'meterya.selected-meter.${Uri.encodeComponent(repository.subject ?? 'local')}.${workspace!.id}';
  Point? get preferredPoint {
    final scope = _meterScope;
    final id = scope == null ? null : meterSelections.selected(scope);
    return points.where((p) => p.id == id).firstOrNull ??
        activePoints.firstOrNull ??
        points.firstOrNull;
  }

  void rememberPoint(String id) {
    final scope = _meterScope;
    if (scope != null && points.any((p) => p.id == id)) {
      meterSelections.select(scope, id);
    }
  }

  int _billingYear = DateTime.now().year;
  int get billingYear => _billingYear;
  List<int> get billingYears => ({
    DateTime.now().year,
    _billingYear,
    ...points.expand((p) => p.annual ?? <AnnualSummary>[]).map((s) => s.year),
    ...points.expand((p) => p.monthlyBilling).map((s) => s.year),
    ...points.expand((p) => p.readings).map((r) => DateTime.parse(r.date).year),
  }.toList()..sort((a, b) => b.compareTo(a)));
  void selectBillingYear(int year) {
    if (_billingYear == year) return;
    _billingYear = year;
    notifyListeners();
  }

  List<Point> get physicalPoints => points.where((p) => !p.isVirtual).toList();
  List<Point> get activePhysicalPoints =>
      physicalPoints.where((p) => !p.archived).toList();
  List<Point> get activePoints => points.where((p) => !p.archived).toList();
  List<Point> get archivedPoints => points.where((p) => p.archived).toList();

  Future<void> _loadWorkspace(Workspace? selected) async {
    final loaded = selected == null
        ? <Point>[]
        : await repository.points(selected.id);
    final hasHeat =
        selected != null && await repository.hasHeatConfiguration(selected.id);
    final transitions = selected == null
        ? <MeterTransition>[]
        : await repository.transitions(selected.id);
    workspace = selected;
    points = loaded;
    hasHeatConfiguration = hasHeat;
    meterTransitions = transitions;
  }

  List<Point> pointsForYear(int year) => points.where((point) {
    final starts =
        meterTransitions
            .where((t) => t.newPoints.contains(point.id))
            .map((t) => t.date)
            .toList()
          ..sort();
    final ends =
        meterTransitions
            .where((t) => t.oldPoint == point.id)
            .map((t) => t.date)
            .toList()
          ..sort();
    final dates = point.readings.map((r) => r.date).toList()..sort();
    final start = starts.firstOrNull ?? dates.firstOrNull;
    final end = ends.firstOrNull ?? (point.archived ? dates.lastOrNull : null);
    final hasYearData =
        point.annual?.any(
          (s) => s.year == year && s.positions.any((p) => p.from.isNotEmpty),
        ) ==
        true;
    if (start == null) {
      return hasYearData || (!point.archived && year == DateTime.now().year);
    }
    return start.compareTo('${year + 1}-01-01') < 0 &&
        (end == null || end.compareTo('$year-01-01') > 0);
  }).toList();

  Future<void> _refresh() async {
    final selected = workspace?.id;
    workspaces = await repository.session();
    signedIn = true;
    final nextWorkspace =
        workspaces.where((w) => w.id == selected).firstOrNull ??
        workspaces.firstOrNull;
    await _loadWorkspace(nextWorkspace);
  }

  Future<void> refresh() => run(_refresh).then((_) {});
  Future<bool> createWorkspace(String name, String key) => run(() async {
    final created = await repository.createWorkspace(name, key);
    workspace = created;
    await _refresh();
  });
  Future<bool> manageMember(
    String ws,
    WorkspaceMember member,
    int version,
    String key, {
    String? role,
  }) => run(() async {
    await repository.manageMember(ws, member, version, key, role: role);
    await _refresh();
  });
  Future<bool> setMemberActive(
    String ws,
    WorkspaceMember member,
    int version,
    String key,
    bool active,
  ) => run(() async {
    await repository.setMemberActive(ws, member, version, key, active);
    await _refresh();
  });
  Future<bool> renameWorkspace(Workspace target, String name, String key) =>
      run(() async {
        await repository.renameWorkspace(target, name, key);
        await _refresh();
      });
  Future<bool> managePoint(
    Point point,
    String action,
    String key, {
    String? name,
    String? serial,
  }) => run(() async {
    await repository.managePoint(
      workspace!.id,
      point,
      action,
      key,
      name: name,
      serial: serial,
    );
    points = await repository.points(workspace!.id);
  });

  Future<bool> run(Future<void> Function() action) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on ApiException catch (e) {
      error = e.code;
      if (e.code == 'AUTHENTICATION_REQUIRED') {
        signedIn = false;
        repository.api.csrf = null;
      }
      return false;
    } catch (_) {
      error = 'INTERNAL_ERROR';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> saveVirtual(
    Map<String, dynamic> definition,
    String key, {
    Point? existing,
  }) => run(() async {
    await repository.saveVirtual(
      workspace!.id,
      definition,
      key,
      existing: existing,
    );
    await _refresh();
  });
  Future<bool> removeVirtual(Point point, String key) => run(() async {
    await repository.removeVirtual(workspace!.id, point, key);
    await _refresh();
  });
  Future<bool> movePoint(Point point, Workspace target, String key) =>
      run(() async {
        await repository.movePoint(workspace!.id, point, target.id, key);
        await _refresh();
      });

  Future<bool> purgePoint(Point point, String key) => run(() async {
    await repository.purgePoint(workspace!.id, point, key);
    points = await repository.points(workspace!.id);
  });

  Future<void> initialize({String? invitationToken}) => run(() async {
    workspaces = await repository.session();
    signedIn = true;
    if (invitationToken != null) {
      await repository.accept(invitationToken);
      workspaces = await repository.session();
    }
    await _loadWorkspace(workspaces.firstOrNull);
  }).then((_) {});
  Future<void> select(Workspace selected) => run(() async {
    await _loadWorkspace(selected);
  }).then((_) {});
  Future<bool> create(String name, String serial, String type, String key) =>
      run(() async {
        await repository.create(workspace!.id, name, serial, type, key);
        points = await repository.points(workspace!.id);
      });
  Future<bool> record(
    Point point,
    Register register,
    String date,
    String value,
    String key,
  ) => run(() async {
    await repository.record(workspace!.id, point, register, date, value, key);
    points = await repository.points(workspace!.id);
  });
  bool canChangeReading(Reading reading) =>
      signedIn &&
      workspace?.canRecord == true &&
      reading.id != null &&
      (workspace?.isAdmin == true ||
          (repository.subject != null && reading.actor == repository.subject));
  Future<bool> changeReading(
    Point point,
    Reading reading,
    String key, {
    required bool retract,
    required String reason,
    String? date,
    String? value,
  }) => run(() async {
    final ws = workspace!.id;
    await repository.changeReading(
      ws,
      point,
      reading,
      key,
      retract: retract,
      reason: reason,
      date: date,
      value: value,
    );
    points = await repository.points(ws);
  });
  Future<bool> saveTariffs(Point point, Tariffs tariffs, String key) =>
      run(() async {
        await repository.saveTariffs(workspace!.id, point, tariffs, key);
        points = await repository.points(workspace!.id);
      });
}
