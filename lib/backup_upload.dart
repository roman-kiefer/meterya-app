import 'api_service.dart';

class BackupUpload {
  final String name;
  final Future<Map<String, dynamic>> Function(ApiService api) upload;
  const BackupUpload(this.name, this.upload);
}
