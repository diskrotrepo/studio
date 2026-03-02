import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

part 'health_service.g.dart';

class HealthService {
  HealthService();

  Router get router => _$HealthServiceRouter(this);

  @Route.get('/status')
  Future<Response> status(Request request) async {
    return Response.ok('The server is healthy!');
  }
}
