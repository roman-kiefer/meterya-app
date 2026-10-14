class AuditReference {
  final String id, kind;
  final String? name;
  final String? status;
  const AuditReference(this.id, this.kind, this.name, {this.status});
  factory AuditReference.fromJson(Map<String, dynamic> value) => AuditReference(
    value['id'] as String,
    value['kind'] as String,
    value['name'] as String?,
    status: value['status'] as String?,
  );
}

class AuditDetail {
  final String field, value, format;
  const AuditDetail(this.field, this.value, this.format);
  factory AuditDetail.fromJson(Map<String, dynamic> value) => AuditDetail(
    value['field'] as String,
    value['value'] as String,
    value['format'] as String,
  );
}

class AuditEntry {
  final String id, type, action, workspaceId, workspaceName;
  final DateTime occurredAt;
  final AuditReference actor, object;
  final List<AuditDetail> details;
  AuditEntry.fromJson(Map<String, dynamic> value)
    : id = value['id'] as String,
      type = value['event_type'] as String,
      action = value['action'] as String,
      workspaceId = value['workspace_id'] as String,
      workspaceName = value['workspace_name'] as String,
      occurredAt = DateTime.parse(value['occurred_at'] as String),
      actor = AuditReference.fromJson(value['actor'] as Map<String, dynamic>),
      object = AuditReference.fromJson(value['object'] as Map<String, dynamic>),
      details = (value['details'] as List)
          .map((d) => AuditDetail.fromJson(d as Map<String, dynamic>))
          .toList();
}

class AuditPage {
  final List<AuditEntry> entries;
  final List<String> types;
  final String? next;
  AuditPage.fromJson(Map<String, dynamic> value)
    : entries = (value['entries'] as List)
          .map((e) => AuditEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      types = (value['event_types'] as List).cast<String>(),
      next = value['next_cursor'] as String?;
}
