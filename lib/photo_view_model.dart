import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;
import 'package:uuid/uuid.dart';
import 'api_service.dart';
import 'photo_model.dart';
import 'repository.dart';

class PhotoViewModel extends ChangeNotifier {
  final Repository repository;
  final String workspace;
  PhotoProposal? proposal;
  Uint8List? preview;
  String? error;
  bool busy = false, saved = false, _disposed = false;
  int width = 1, height = 1;
  final String uploadKey = const Uuid().v4();
  String confirmKey = const Uuid().v4();
  PhotoViewModel(this.repository, this.workspace);
  void changed() {
    confirmKey = const Uuid().v4();
  }

  Future<bool> loadPreview() => _run(() async {
    preview = await repository.api.photoBytes(proposal!.photo.previewURL);
    width = proposal!.photo.width;
    height = proposal!.photo.height;
  });
  Future<bool> render(List<Map<String, dynamic>> edits) => _run(() async {
    final bytes = await repository.workingPhoto(
      workspace,
      proposal!.photo.id,
      edits,
    );
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      width = frame.image.width;
      height = frame.image.height;
      frame.image.dispose();
      preview = bytes;
    } finally {
      codec.dispose();
    }
  });

  Future<bool> upload(Uint8List raw) => _run(() async {
    proposal = await repository.uploadPhoto(workspace, raw, uploadKey);
    if (_disposed) {
      await discard();
      return;
    }
    preview = await repository.api.photoBytes(proposal!.photo.previewURL);
    width = proposal!.photo.width;
    height = proposal!.photo.height;
  });
  Future<bool> analyze(Map<String, dynamic> selection) => _run(() async {
    proposal = await repository.analyzePhoto(
      workspace,
      proposal!.photo.id,
      selection,
    );
  });
  Future<bool> save(Map<String, dynamic> selection) => _run(() async {
    await repository.confirmPhoto(
      workspace,
      proposal!.photo.id,
      selection,
      confirmKey,
    );
    saved = true;
  });
  Future<void> discard() async {
    if (!saved && proposal != null) {
      try {
        await repository.discardPhoto(workspace, proposal!.photo.id);
      } catch (_) {
        /* Expired drafts are removed by the server. */
      }
    }
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
