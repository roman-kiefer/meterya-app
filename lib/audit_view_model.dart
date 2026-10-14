import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'audit_model.dart';
import 'repository.dart';

/// Filter changes invalidate pending requests, including stale errors.
class AuditViewModel extends ChangeNotifier {
  final Repository repository;
  AuditViewModel(this.repository);
  List<AuditEntry> entries = [];
  List<String> types = [];
  String? workspaceId, next, error;
  String eventType = '';
  bool busy = false, enabled = false;
  int _generation = 0;
  bool _disposed = false;

  Future<void> configure(String? workspace, bool allowed) async {
    if (workspaceId == workspace && enabled == allowed) return;
    workspaceId = workspace;
    enabled = allowed;
    eventType = '';
    types = [];
    await load();
  }

  Future<void> filter(String type) async {
    eventType = type;
    await load();
  }

  Future<void> load({bool more = false}) async {
    if (more && (busy || next == null)) return;
    final generation = ++_generation;
    final cursor = more ? next : null;
    if (!more) {
      entries = [];
      next = null;
    }
    error = null;
    busy = enabled;
    notifyListeners();
    if (!enabled) return;
    try {
      final page = await repository.audit(workspaceId, eventType, cursor);
      if (_disposed || generation != _generation) return;
      entries = more ? [...entries, ...page.entries] : page.entries;
      types = page.types;
      next = page.next;
    } on ApiException catch (e) {
      if (_disposed || generation != _generation) return;
      error = e.code;
      if (const [
        'PERMISSION_DENIED',
        'MFA_REQUIRED',
        'AUTHENTICATION_REQUIRED',
        'RESOURCE_NOT_FOUND',
      ].contains(e.code)) {
        entries = [];
        next = null;
        types = [];
      }
    } catch (_) {
      if (_disposed || generation != _generation) return;
      error = 'INTERNAL_ERROR';
    }
    busy = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
