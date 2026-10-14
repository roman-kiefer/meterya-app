import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'models.dart';
import 'repository.dart';

class InvitationViewModel extends ChangeNotifier {
  final Repository repository;
  final String workspace;
  List<Invitation> invitations = [];
  bool busy = false;
  String? error;
  InvitationViewModel(this.repository, this.workspace);
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> run(Future<void> Function() action) async {
    if (busy) return false;
    busy = true;
    error = null;
    _notify();
    try {
      await action();
      invitations = await repository.invitations(workspace);
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

  Future<bool> load() => run(() async {});
  Future<bool> invite(String email, String role, String key) =>
      run(() => repository.invite(workspace, email, role, key));
  Future<bool> change(Invitation invitation, bool revoke) =>
      run(() => repository.changeInvite(workspace, invitation, revoke));
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
