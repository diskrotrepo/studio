// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_service.dart';

// **************************************************************************
// ShelfRouterGenerator
// **************************************************************************

Router _$UserServiceRouter(UserService service) {
  final router = Router();
  router.add('GET', r'/me', service.me);
  router.add('GET', r'/<userId>', service.getUser);
  return router;
}
