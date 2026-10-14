import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'models.dart';
import 'repository.dart';
import 'transition_model.dart';

class TransitionViewModel extends ChangeNotifier {
  final Repository repository;
  final String workspace;
  List<MeterTransition> records = [];
  bool busy = false;
  String? error;
  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  TransitionViewModel(this.repository, this.workspace);
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
    records = await repository.transitions(workspace);
  });
  Future<bool> save(
    Workspace ws,
    Point old,
    List<Point> replacements,
    String date,
    String key, {
    String? continuation,
  }) => _run(() async {
    await repository.recordTransition(
      ws,
      old,
      replacements,
      date,
      key,
      continuation: continuation,
    );
    records = await repository.transitions(workspace);
  });
}
