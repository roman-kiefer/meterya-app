import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'api_service.dart';

Future<Uint8List?> pickReadingPhoto({bool camera = false}) async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/jpeg,image/png,image/webp';
  if (camera) input.setAttribute('capture', 'environment');
  final result = Completer<Uint8List?>();
  input.addEventListener(
    'cancel',
    ((web.Event _) {
      if (!result.isCompleted) result.complete(null);
    }).toJS,
  );
  input.addEventListener(
    'change',
    ((web.Event _) {
      () async {
        try {
          final file = input.files?.item(0);
          if (file == null) {
            result.complete(null);
            return;
          }
          if (file.size > 20 * 1024 * 1024) {
            throw const ApiException('PHOTO_TOO_LARGE');
          }
          final buffer = (await file.arrayBuffer().toDart).toDart;
          result.complete(buffer.asUint8List());
        } catch (e, s) {
          if (!result.isCompleted) result.completeError(e, s);
        }
      }();
    }).toJS,
  );
  input.click();
  return result.future;
}
