import 'dart:convert';

import 'package:studio_backend/src/server_backends/server_backend_repository.dart';
import 'package:studio_backend/src/utils/shelf_helper.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class ServerBackendService {
  ServerBackendService({required ServerBackendRepository repository})
      : _repository = repository;

  final ServerBackendRepository _repository;

  Router get router {
    final r = Router();
    r.get('/', _getAll);
    r.post('/', _create);
    r.put('/<id>', _update);
    r.delete('/<id>', _delete);
    r.put('/<id>/activate', _activate);
    return r;
  }

  Future<Response> _getAll(Request request) async {
    final backends = await _repository.getAll();
    final data = backends
        .map((b) => {
              'id': b.id,
              'name': b.name,
              'api_host': b.apiHost,
              'secure': b.secure,
              'is_active': b.isActive,
              'created_at': b.createdAt.dateTime.toIso8601String(),
            })
        .toList();
    return jsonOk({'data': data});
  }

  Future<Response> _create(Request request) async {
    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;

    final name = body['name'] as String?;
    final apiHost = body['api_host'] as String?;
    final secure = body['secure'] as bool? ?? false;

    if (name == null || name.isEmpty) {
      return jsonErr(400, {'message': 'name is required'});
    }
    if (apiHost == null || apiHost.isEmpty) {
      return jsonErr(400, {'message': 'api_host is required'});
    }

    final backend = await _repository.create(
      name: name,
      apiHost: apiHost,
      secure: secure,
    );

    return jsonOk({
      'id': backend.id,
      'name': backend.name,
      'api_host': backend.apiHost,
      'secure': backend.secure,
      'is_active': backend.isActive,
      'created_at': backend.createdAt.dateTime.toIso8601String(),
    });
  }

  Future<Response> _update(Request request, String id) async {
    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;

    final name = body['name'] as String?;
    final apiHost = body['api_host'] as String?;
    final secure = body['secure'] as bool?;

    await _repository.update(
      id: id,
      name: name,
      apiHost: apiHost,
      secure: secure,
    );

    return jsonOk({'success': true});
  }

  Future<Response> _delete(Request request, String id) async {
    final active = await _repository.getActive();
    if (active != null && active.id == id) {
      // Deactivate before deleting so the caller knows to revert to local.
      await _repository.deactivate(id);
    }

    await _repository.delete(id);
    return jsonOk({'success': true});
  }

  Future<Response> _activate(Request request, String id) async {
    await _repository.setActive(id);
    return jsonOk({'success': true});
  }
}
