import 'dart:convert';

import 'package:studio_backend/src/settings/settings_repository.dart';
import 'package:studio_backend/src/user/user_repository.dart';
import 'package:studio_backend/src/utils/shelf_helper.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

part 'user_service.g.dart';

class UserService {
  UserService({
    required UserRepository userRepository,
    required SettingsRepository settingsRepository,
  }) : _userRepository = userRepository,
       _settingsRepository = settingsRepository;

  final UserRepository _userRepository;
  final SettingsRepository _settingsRepository;

  Router get router => _$UserServiceRouter(this);

  @Route.get('/me')
  Future<Response> me(Request request) async {
    final externalUserId = await _settingsRepository.getExternalUserId();
    return Response.ok(
      jsonEncode({'user_id': externalUserId}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  @Route.get('/<userId>')
  Future<Response> getUser(Request request, String userId) async {
    if (!request.isAdmin) {
      return Response.forbidden(
        'This action requires admin privileges',
        headers: {'Content-Type': 'application/json'},
      );
    }

    final user = await _userRepository.getUser(userId: userId);
    return Response.ok(
      jsonEncode(user),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
