class MeterTransition {
  final String id, date, oldPoint;
  final List<String> newPoints;
  MeterTransition.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      date = j['date'] as String,
      oldPoint = j['old_point'] as String,
      newPoints = (j['new_points'] as List).cast<String>();
}
