import 'package:studio_ui/services/api_client.dart';

class UserIdManager {
  UserIdManager._(this.userId);

  final String userId;

  /// Fetch the server-assigned external user ID.
  static Future<UserIdManager> initialize(ApiClient apiClient) async {
    final id = await apiClient.getUserId();
    return UserIdManager._(id);
  }
}
