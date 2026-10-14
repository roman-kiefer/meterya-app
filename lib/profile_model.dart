import 'package:flutter/foundation.dart';
import 'api_service.dart';

class UserProfile {
  final String username, firstName, lastName, email;
  final bool emailVerified;
  final Map<String, bool> authenticationMethods;
  const UserProfile({
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.emailVerified,
    required this.authenticationMethods,
  });
  factory UserProfile.fromJson(Map<String, dynamic> value) => UserProfile(
    username: value['username'] as String? ?? '',
    firstName: value['firstName'] as String? ?? '',
    lastName: value['lastName'] as String? ?? '',
    email: value['email'] as String? ?? '',
    emailVerified: value['emailVerified'] == true,
    authenticationMethods: {
      for (final entry
          in (value['authenticationMethods'] as Map<String, dynamic>? ?? {})
              .entries)
        entry.key: entry.value == true,
    },
  );
}

class ProfileRepository {
  final ApiService api;
  const ProfileRepository(this.api);
  Future<UserProfile> load() async => UserProfile.fromJson(
    await api.request('/api/v1/profile') as Map<String, dynamic>,
  );
  Future<UserProfile> save(String first, String last) async =>
      UserProfile.fromJson(
        await api.request(
              '/api/v1/profile',
              body: {'firstName': first.trim(), 'lastName': last.trim()},
            )
            as Map<String, dynamic>,
      );
}

class ProfileModel extends ChangeNotifier {
  final ProfileRepository repository;
  UserProfile? profile;
  bool busy = false, _disposed = false;
  String? error;
  ProfileModel(this.repository);
  Future<bool> load() => _run(repository.load);
  Future<bool> save(String first, String last) =>
      _run(() => repository.save(first, last));
  Future<bool> _run(Future<UserProfile> Function() action) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final value = await action();
      if (_disposed) return false;
      profile = value;
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
