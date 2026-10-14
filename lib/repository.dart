import 'api_service.dart';
import 'dart:typed_data';
import 'photo_model.dart';
import 'audit_model.dart';
import 'models.dart';
import 'transition_model.dart';
import 'heat_model.dart';

class Repository {
  final ApiService api;
  Repository(this.api);
  Future<Uint8List> workingPhoto(
    String ws,
    String id,
    List<Map<String, dynamic>> edits,
  ) => api.workingPhoto(ws, id, edits);
  Future<PhotoProposal> uploadPhoto(
    String ws,
    Uint8List bytes,
    String key,
  ) async => PhotoProposal.fromJson(await api.uploadPhoto(ws, bytes, key));
  Future<PhotoProposal> analyzePhoto(
    String ws,
    String id,
    Map<String, dynamic> selection,
  ) async => PhotoProposal.fromJson(
    await api.request(
          '/api/v1/workspaces/$ws/photos/$id/analyze',
          body: selection,
        )
        as Map<String, dynamic>,
  );
  Future<void> confirmPhoto(
    String ws,
    String id,
    Map<String, dynamic> selection,
    String key,
  ) async {
    await api.request(
      '/api/v1/workspaces/$ws/photos/$id/confirm',
      body: selection,
      idempotencyKey: key,
    );
  }

  Future<void> discardPhoto(String ws, String id) async {
    await api.request('/api/v1/workspaces/$ws/photos/$id/discard', body: {});
  }

  Future<AuditPage> audit(String? ws, String type, String? cursor) async {
    final path = ws == null ? '/api/v1/audit' : '/api/v1/workspaces/$ws/audit';
    final uri = Uri(
      path: path,
      queryParameters: {
        if (type.isNotEmpty) 'event_type': type,
        'cursor': ?cursor,
      },
    );
    return AuditPage.fromJson(
      await api.request(uri.toString()) as Map<String, dynamic>,
    );
  }

  bool isOperator = false;
  String? subject;
  Future<bool> hasHeatConfiguration(String ws) async =>
      (await api.request('/api/v1/workspaces/$ws/power-to-heat') as List)
          .isNotEmpty;
  Future<List<HeatReport>> heatReports(String ws) async =>
      (await api.request('/api/v1/workspaces/$ws/power-to-heat') as List)
          .map((v) => HeatReport.fromJson(v as Map<String, dynamic>))
          .toList();
  Future<void> configureHeat(
    Workspace ws,
    String name,
    String from,
    Point net,
    Point house,
    String key,
  ) async {
    await api.request(
      '/api/v1/workspaces/${ws.id}/power-to-heat',
      body: {
        'name': name,
        'valid_from': from,
        'net_point': net.id,
        'house_point': house.id,
        'expected_version': ws.version,
        'expected_point_versions': {
          net.id: net.version,
          house.id: house.version,
        },
      },
      idempotencyKey: key,
    );
  }

  Future<List<MeterTransition>> transitions(String ws) async =>
      (await api.request('/api/v1/workspaces/$ws/transitions') as List)
          .map((v) => MeterTransition.fromJson(v as Map<String, dynamic>))
          .toList();
  Future<void> recordTransition(
    Workspace ws,
    Point old,
    List<Point> replacements,
    String date,
    String key, {
    String? continuation,
  }) async {
    await api.request(
      '/api/v1/workspaces/${ws.id}/transitions',
      body: {
        'date': date,
        'continuation_point': ?continuation,
        'old_point': old.id,
        'new_points': replacements.map((p) => p.id).toList(),
        'expected_version': ws.version,
        'expected_point_versions': {
          old.id: old.version,
          for (final p in replacements) p.id: p.version,
        },
      },
      idempotencyKey: key,
    );
  }

  Future<Workspace> createWorkspace(String name, String key) async =>
      Workspace.fromJson(
        await api.request(
              '/api/v1/workspaces',
              body: {'name': name},
              idempotencyKey: key,
            )
            as Map<String, dynamic>,
      );
  Future<Memberships> members(String workspace) async => Memberships.fromJson(
    await api.request('/api/v1/workspaces/$workspace/members')
        as Map<String, dynamic>,
  );
  Future<void> manageMember(
    String workspace,
    WorkspaceMember member,
    int version,
    String key, {
    String? role,
  }) async {
    await api.request(
      '/api/v1/workspaces/$workspace/members/${role == null ? 'remove' : 'role'}',
      body: {
        'subject': member.subject,
        'expected_version': version,
        'role': ?role,
      },
      idempotencyKey: key,
    );
  }

  Future<List<Invitation>> invitations(String workspace) async =>
      (await api.request('/api/v1/workspaces/$workspace/invitations') as List)
          .map((i) => Invitation.fromJson(i as Map<String, dynamic>))
          .toList();
  Future<void> invite(
    String workspace,
    String email,
    String role,
    String key,
  ) async {
    await api.request(
      '/api/v1/workspaces/$workspace/invitations',
      body: {'email': email, 'role': role},
      idempotencyKey: key,
    );
  }

  Future<void> changeInvite(
    String workspace,
    Invitation invitation,
    bool revoke,
  ) async {
    await api.request(
      '/api/v1/workspaces/$workspace/invitations/${invitation.id}/${revoke ? 'revoke' : 'retry'}',
      body: {'expected_version': invitation.version},
    );
  }

  Future<void> setMemberActive(
    String workspace,
    WorkspaceMember member,
    int version,
    String key,
    bool active,
  ) async {
    await api.request(
      '/api/v1/workspaces/$workspace/members/activity',
      body: {
        'subject': member.subject,
        'expected_version': version,
        'active': active,
      },
      idempotencyKey: key,
    );
  }

  Future<void> deleteInvite(String workspace, Invitation invitation) async {
    await api.request(
      '/api/v1/workspaces/$workspace/invitations/${invitation.id}/delete',
      body: {'expected_version': invitation.version},
    );
  }

  Future<void> changeReading(
    String workspace,
    Point point,
    Reading reading,
    String key, {
    required bool retract,
    required String reason,
    String? date,
    String? value,
  }) async {
    await api.request(
      '/api/v1/workspaces/$workspace/points/${point.id}/readings/${reading.id}/${retract ? 'retract' : 'correct'}',
      body: {
        'expected_version': point.version,
        'reason': reason,
        if (!retract) 'date': date,
        if (!retract) 'value': value,
      },
      idempotencyKey: key,
    );
  }

  Future<List<Workspace>> session() async {
    final data = await api.request('/api/v1/me') as Map<String, dynamic>;
    api.csrf = data['csrf_token'] as String;
    isOperator = data['operator'] == true;
    subject = data['subject'] as String?;
    return (data['workspaces'] as List)
        .map((w) => Workspace.fromJson(w as Map<String, dynamic>))
        .toList();
  }

  Future<List<Point>> points(String workspace) async =>
      (await api.request(
                '/api/v1/workspaces/$workspace/points?include_archived=true',
              )
              as List)
          .map((p) => Point.fromJson(p as Map<String, dynamic>))
          .toList();
  Future<void> create(
    String workspace,
    String name,
    String serial,
    String type,
    String key,
  ) async {
    await api.request(
      '/api/v1/workspaces/$workspace/points',
      body: {'name': name, 'serial': serial, 'type': type},
      idempotencyKey: key,
    );
  }

  Future<void> record(
    String workspace,
    Point point,
    Register register,
    String date,
    String value,
    String key,
  ) async {
    await api.request(
      '/api/v1/workspaces/$workspace/points/${point.id}/readings',
      body: {
        'register_id': register.id,
        'date': date,
        'value': value,
        'expected_version': point.version,
      },
      idempotencyKey: key,
    );
  }

  Future<void> accept(String token) async {
    await api.request('/api/v1/invitations/accept', body: {'token': token});
  }

  Future<void> renameWorkspace(
    Workspace workspace,
    String name,
    String key,
  ) async {
    await api.request(
      '/api/v1/workspaces/${workspace.id}/rename',
      body: {'name': name, 'expected_version': workspace.version},
      idempotencyKey: key,
    );
  }

  Future<void> managePoint(
    String workspace,
    Point point,
    String action,
    String key, {
    String? name,
    String? serial,
  }) async {
    await api.request(
      '/api/v1/workspaces/$workspace/points/${point.id}/$action',
      body: {
        'expected_version': point.version,
        'name': ?name,
        'serial': ?serial,
      },
      idempotencyKey: key,
    );
  }

  Future<void> saveTariffs(
    String workspace,
    Point point,
    Tariffs tariffs,
    String key,
  ) async {
    await api.request(
      '/api/v1/workspaces/$workspace/points/${point.id}/tariffs',
      body: {'tariffs': tariffs.toJson(), 'expected_version': point.version},
      idempotencyKey: key,
    );
  }

  Future<Map<String, dynamic>> virtualCandidates(String ws) async =>
      await api.request('/api/v1/workspaces/$ws/virtual-points')
          as Map<String, dynamic>;
  Future<void> saveVirtual(
    String ws,
    Map<String, dynamic> definition,
    String key, {
    Point? existing,
  }) async {
    await api.request(
      '/api/v1/workspaces/$ws/virtual-points${existing == null ? '' : '/${existing.id}/save'}',
      body: {
        'definition': definition,
        'expected_version': existing?.version ?? 0,
      },
      idempotencyKey: key,
    );
  }

  Future<void> removeVirtual(String ws, Point point, String key) async {
    await api.request(
      '/api/v1/workspaces/$ws/virtual-points/${point.id}/remove',
      body: {'expected_version': point.version},
      idempotencyKey: key,
    );
  }

  Future<void> movePoint(
    String workspace,
    Point point,
    String target,
    String key,
  ) async {
    await api.request(
      '/api/v1/workspaces/$workspace/points/${point.id}/move',
      body: {'target_workspace_id': target, 'expected_version': point.version},
      idempotencyKey: key,
    );
  }

  Future<void> purgePoint(String workspace, Point point, String key) async {
    await api.request(
      '/api/v1/workspaces/$workspace/points/${point.id}/purge',
      body: {'expected_version': point.version, 'confirm_point_id': point.id},
      idempotencyKey: key,
    );
  }
}
