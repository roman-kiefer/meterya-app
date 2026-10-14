import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class ApiException implements Exception {
  final String code;
  const ApiException(this.code);
}

class ApiService {
  final http.Client client;
  final Uri base;
  String? csrf;
  ApiService(this.client, this.base);

  Future<void> restoreArchive(String job, String hash) async {
    final response = await client.post(
      base.resolve('/api/v1/operator/backup/jobs/$job/restore'),
      headers: {
        'X-CSRF-Token': csrf ?? '',
        'X-Backup-Confirm': 'RESTORE',
        'X-Backup-SHA256': hash,
      },
    );
    if (response.statusCode >= 400) {
      throw ApiException(
        (jsonDecode(response.body) as Map<String, dynamic>)['code']
                as String? ??
            'INTERNAL_ERROR',
      );
    }
  }

  Future<Uint8List> photoBytes(String path) async {
    final response = await client.get(base.resolve(path));
    if (response.statusCode >= 400) {
      throw ApiException(
        (jsonDecode(response.body) as Map<String, dynamic>)['code']
                as String? ??
            'INTERNAL_ERROR',
      );
    }
    return response.bodyBytes;
  }

  Future<Uint8List> workingPhoto(
    String ws,
    String id,
    List<Map<String, dynamic>> edits,
  ) async {
    final response = await client.post(
      base.resolve('/api/v1/workspaces/$ws/photos/$id/working'),
      headers: {'Content-Type': 'application/json', 'X-CSRF-Token': csrf ?? ''},
      body: jsonEncode({'edits': edits}),
    );
    if (response.statusCode >= 400) {
      throw ApiException(
        (jsonDecode(response.body) as Map<String, dynamic>)['code']
                as String? ??
            'INTERNAL_ERROR',
      );
    }
    return response.bodyBytes;
  }

  Future<Map<String, dynamic>> uploadPhoto(
    String ws,
    Uint8List bytes,
    String key,
  ) async {
    final response = await client.post(
      base.resolve('/api/v1/workspaces/$ws/photos'),
      headers: {
        'Content-Type': 'application/octet-stream',
        'X-CSRF-Token': csrf ?? '',
        'Idempotency-Key': key,
      },
      body: bytes,
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(data['code'] as String? ?? 'INTERNAL_ERROR');
    }
    return data;
  }

  Future<Map<String, dynamic>> backupRequest(
    String contents, {
    String? confirmedHash,
  }) async {
    final response = await client.post(
      base.resolve(
        '/api/v1/operator/backup/${confirmedHash == null ? 'validate' : 'restore'}',
      ),
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrf ?? '',
        'X-Backup-SHA256': ?confirmedHash,
        if (confirmedHash != null) 'X-Backup-Confirm': 'RESTORE',
      },
      // Keep the file intact: JSON decoding in JavaScript could round large integers.
      body: utf8.encode(contents),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(data['code'] as String? ?? 'INTERNAL_ERROR');
    }
    return data;
  }

  Future<dynamic> request(
    String path, {
    Map<String, dynamic>? body,
    String? idempotencyKey,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    final url = base.resolve(path);
    final http.Response response;
    if (body == null) {
      response = await client.get(url, headers: headers);
    } else {
      headers.addAll({
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrf ?? '',
        'Idempotency-Key': idempotencyKey ?? const Uuid().v4(),
      });
      response = await client.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );
    }
    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw const ApiException('INTERNAL_ERROR');
    }
    if (response.statusCode >= 400) {
      throw ApiException(
        data is Map
            ? data['code'] as String? ?? 'INTERNAL_ERROR'
            : 'INTERNAL_ERROR',
      );
    }
    return data;
  }
}
