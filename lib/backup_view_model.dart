import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'backup_upload.dart';

class BackupViewModel extends ChangeNotifier {
  final ApiService api;
  String? filename, contents, error;
  Map<String, dynamic>? preview;
  bool busy = false, restored = false;
  bool _disposed = false;
  String? archiveId;
  int completed = 0, total = 0;
  BackupViewModel(this.api);

  void clearSelection() {
    if (busy) return;
    filename = null;
    archiveId = null;
    contents = null;
    preview = null;
    error = null;
    notifyListeners();
  }

  Future<bool> validate(String name, String text) async {
    if (busy) return false;
    archiveId = null;
    filename = null;
    contents = null;
    preview = null;
    return _run(() async {
      final result = await api.backupRequest(text);
      filename = name;
      contents = text;
      preview = result;
    });
  }

  Future<bool> restore() async {
    if (busy ||
        (contents == null && archiveId == null) ||
        preview == null ||
        restored) {
      return false;
    }
    return _run(() async {
      if (archiveId != null) {
        await api.restoreArchive(archiveId!, preview!['sha256'] as String);
      } else {
        await api.backupRequest(
          contents!,
          confirmedHash: preview!['sha256'] as String,
        );
      }
      restored = true;
      contents = null;
      preview = null;
      api.csrf = null;
    });
  }

  Future<Map<String, dynamic>> _waitJob(Map<String, dynamic> job) async {
    final deadline = DateTime.now().add(const Duration(minutes: 21));
    while (job['status'] == 'PREPARING') {
      if (_disposed || DateTime.now().isAfter(deadline)) {
        throw const ApiException('BACKUP_NOT_READY');
      }
      completed = job['completed'] as int? ?? 0;
      total = job['total'] as int? ?? 0;
      notifyListeners();
      await Future<void>.delayed(const Duration(seconds: 1));
      job =
          await api.request('/api/v1/operator/backup/jobs/${job['id']}')
              as Map<String, dynamic>;
    }
    if (job['status'] != 'READY') {
      throw ApiException(job['error'] as String? ?? 'INTERNAL_ERROR');
    }
    return job;
  }

  Future<String?> prepareDownload() async {
    String? url;
    await _run(() async {
      final job = await _waitJob(
        await api.request('/api/v1/operator/backup/jobs', body: {})
            as Map<String, dynamic>,
      );
      url = job['download_url'] as String;
    });
    return url;
  }

  Future<bool> validateArchive(BackupUpload file) async {
    clearSelection();
    return _run(() async {
      final job = await _waitJob(await file.upload(api));
      filename = file.name;
      archiveId = job['id'] as String;
      preview = job['info'] as Map<String, dynamic>;
    });
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (busy || _disposed) return false;
    busy = true;
    error = null;
    notifyListeners();
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
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
