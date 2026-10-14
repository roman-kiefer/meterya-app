import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'models.dart';
import 'repository.dart';
import 'heat_model.dart';

class HeatViewModel extends ChangeNotifier {
  final Repository repository;
  final String workspace;
  List<HeatReport> reports = [];
  bool busy = false, _disposed = false;
  String? error;
  HeatViewModel(this.repository, this.workspace);
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (busy) return false;
    busy = true;
    error = null;
    _notify();
    try {
      await action();
      return true;
    } on ApiException catch (e) {
      error = e.code;
      return false;
    } catch (_) {
      error = 'INTERNAL_ERROR';
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> load() => _run(() async {
    reports = await repository.heatReports(workspace);
  });
  Future<bool> configure(
    Workspace ws,
    String name,
    String from,
    Point net,
    Point house,
    String key,
  ) => _run(() async {
    await repository.configureHeat(ws, name, from, net, house, key);
    reports = await repository.heatReports(workspace);
  });
}
