import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'api_service.dart';
import 'backup_upload.dart';
import 'package:uuid/uuid.dart';

Future<BackupUpload?> pickBackupArchive() async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.zip,.json,application/zip,application/json';
  final selected = Completer<BackupUpload?>();
  input.addEventListener(
    'cancel',
    ((web.Event _) {
      if (!selected.isCompleted) selected.complete(null);
    }).toJS,
  );
  input.addEventListener(
    'change',
    ((web.Event _) {
      final file = input.files?.item(0);
      if (file == null) {
        selected.complete(null);
        return;
      }
      if (file.size > 50 * 1024 * 1024 * 1024) {
        selected.completeError(const ApiException('BACKUP_TOO_LARGE'));
        return;
      }
      final key = const Uuid().v4();
      selected.complete(
        BackupUpload(file.name, (api) async {
          final done = Completer<Map<String, dynamic>>();
          final xhr = web.XMLHttpRequest()
            ..open(
              'POST',
              api.base.resolve('/api/v1/operator/backup/uploads').toString(),
            )
            ..withCredentials = true
            ..timeout = 20 * 60 * 1000;
          xhr.setRequestHeader('Content-Type', 'application/octet-stream');
          xhr.setRequestHeader('X-CSRF-Token', api.csrf ?? '');
          xhr.setRequestHeader('Idempotency-Key', key);
          xhr.addEventListener(
            'load',
            ((web.Event _) {
              try {
                final result =
                    jsonDecode(xhr.responseText) as Map<String, dynamic>;
                if (xhr.status >= 400) {
                  throw ApiException(
                    result['code'] as String? ?? 'INTERNAL_ERROR',
                  );
                }
                done.complete(result);
              } catch (e, s) {
                done.completeError(e, s);
              }
            }).toJS,
          );
          for (final event in ['error', 'abort', 'timeout']) {
            xhr.addEventListener(
              event,
              ((web.Event _) {
                if (!done.isCompleted) {
                  done.completeError(const ApiException('INTERNAL_ERROR'));
                }
              }).toJS,
            );
          }
          // Send the native file directly: large archives are never materialized as Dart strings or Base64.
          xhr.send(file);
          return done.future;
        }),
      );
    }).toJS,
  );
  input.click();
  return selected.future;
}

Future<({String name, String contents})?> pickBackupFile() async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.json,application/json';
  final selected = Completer<({String name, String contents})?>();
  input.addEventListener(
    'cancel',
    ((web.Event _) {
      if (!selected.isCompleted) selected.complete(null);
    }).toJS,
  );
  input.addEventListener(
    'change',
    ((web.Event _) {
      () async {
        try {
          final file = input.files?.item(0);
          if (file == null) {
            selected.complete(null);
          } else if (file.size > 32 * 1024 * 1024) {
            selected.completeError(const ApiException('BACKUP_TOO_LARGE'));
          } else {
            final contents = (await file.text().toDart).toDart;
            selected.complete((name: file.name, contents: contents));
          }
        } catch (e, stack) {
          if (!selected.isCompleted) selected.completeError(e, stack);
        }
      }();
    }).toJS,
  );
  input.click();
  return selected.future;
}
