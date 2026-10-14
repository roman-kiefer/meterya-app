class ReadingPhoto {
  final String id, readingId, pointId, registerId, date, value, status;
  final String previewURL, originalURL;
  final String editedURL;
  final int width, height;
  const ReadingPhoto({
    required this.id,
    required this.readingId,
    required this.pointId,
    required this.registerId,
    required this.date,
    required this.value,
    required this.status,
    required this.previewURL,
    required this.originalURL,
    this.editedURL = '',
    required this.width,
    required this.height,
  });
  factory ReadingPhoto.fromJson(Map<String, dynamic> j) => ReadingPhoto(
    id: j['id'] as String,
    readingId: j['reading_id'] as String? ?? '',
    pointId: j['point_id'] as String? ?? '',
    registerId: j['register_id'] as String? ?? '',
    date: j['confirmed_date'] as String? ?? j['captured_date'] as String? ?? '',
    value: j['confirmed_value'] as String? ?? '',
    status: j['status'] as String? ?? '',
    previewURL: j['preview_url'] as String? ?? '',
    originalURL: j['original_url'] as String? ?? '',
    editedURL: j['edited_url'] as String? ?? '',
    width: j['preview_width'] as int? ?? 1,
    height: j['preview_height'] as int? ?? 1,
  );
}

class PhotoProposal {
  final ReadingPhoto photo;
  final String? pointId, registerId, existingReadingId;
  final String value, date;
  final String? existingValue;
  final int version;
  final bool canAttach, canCreate;
  final List<String> flags;
  const PhotoProposal({
    required this.photo,
    this.pointId,
    this.registerId,
    this.existingReadingId,
    required this.value,
    this.existingValue,
    required this.date,
    required this.version,
    required this.canAttach,
    required this.canCreate,
    required this.flags,
  });
  factory PhotoProposal.fromJson(Map<String, dynamic> j) => PhotoProposal(
    photo: ReadingPhoto.fromJson(j['photo'] as Map<String, dynamic>),
    pointId: j['point_id'] as String?,
    registerId: j['register_id'] as String?,
    existingReadingId: j['existing_reading_id'] as String?,
    value: j['value'] as String? ?? '',
    existingValue: j['existing_value'] as String?,
    date: j['date'] as String,
    version: j['expected_version'] as int? ?? 0,
    canAttach: j['can_attach'] == true,
    canCreate: j['can_create'] == true,
    flags: (j['flags'] as List? ?? []).cast<String>(),
  );
}
