import 'package:shelf/shelf.dart';
import 'package:studio_backend/src/user/user_repository.dart';

final _validIdPattern = RegExp(r'^[a-zA-Z0-9\-]{1,100}$');

const _maxKnownUsers = 10000;

Middleware userAutoCreateMiddleware(UserRepository userRepository) {
  final knownUsers = <String>{};

  return (Handler innerHandler) {
    return (Request request) async {
      // Skip user auto-creation for peer requests.
      if (request.headers.containsKey('X-Signature')) {
        return innerHandler(request);
      }

      final externalUserId = request.headers['Diskrot-User-Id'];
      if (externalUserId != null &&
          _validIdPattern.hasMatch(externalUserId) &&
          !knownUsers.contains(externalUserId)) {
        await userRepository.ensureUser(externalUserId: externalUserId);
        if (knownUsers.length < _maxKnownUsers) {
          knownUsers.add(externalUserId);
        }
      }
      return innerHandler(request);
    };
  };
}
