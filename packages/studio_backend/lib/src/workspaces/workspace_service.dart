import 'dart:convert';

import 'package:studio_backend/src/utils/shelf_helper.dart';
import 'package:studio_backend/src/workspaces/workspace_repository.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class WorkspaceService {
  WorkspaceService({required WorkspaceRepository repository})
      : _repository = repository;

  final WorkspaceRepository _repository;

  Router get router {
    final r = Router();
    r.get('/', _getAll);
    r.post('/', _create);
    r.put('/<id>', _rename);
    r.delete('/<id>', _delete);
    return r;
  }

  Future<Response> _getAll(Request request) async {
    // Ensure a default workspace exists (lazy creation on first access).
    await _repository.ensureDefault(request.userId);

    final workspaces = await _repository.getAllByUserId(request.userId);

    // Backfill any songs without a workspace_id into the default.
    final defaultWs = workspaces.firstWhere((w) => w.isDefault);
    await _repository.backfillSongsWithoutWorkspace(
      userId: request.userId,
      workspaceId: defaultWs.id,
    );

    final data = workspaces
        .map((w) => {
              'id': w.id,
              'name': w.name,
              'is_default': w.isDefault,
              'created_at': w.createdAt.dateTime.toIso8601String(),
            })
        .toList();
    return jsonOk({'data': data});
  }

  Future<Response> _create(Request request) async {
    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final name = body['name'] as String?;
    if (name == null || name.isEmpty) {
      return jsonErr(400, {'message': 'name is required'});
    }
    final lengthErr = validateMaxLength(name, 'name', maxLength: 200);
    if (lengthErr != null) {
      return jsonErr(400, {'message': lengthErr});
    }

    final workspace = await _repository.create(
      userId: request.userId,
      name: name,
    );

    return jsonOk({
      'id': workspace.id,
      'name': workspace.name,
      'is_default': workspace.isDefault,
      'created_at': workspace.createdAt.dateTime.toIso8601String(),
    });
  }

  Future<Response> _rename(Request request, String id) async {
    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final name = body['name'] as String?;
    if (name == null || name.isEmpty) {
      return jsonErr(400, {'message': 'name is required'});
    }
    final lengthErr = validateMaxLength(name, 'name', maxLength: 200);
    if (lengthErr != null) {
      return jsonErr(400, {'message': lengthErr});
    }

    final workspace = await _repository.getById(id);
    if (workspace == null || workspace.userId != request.userId) {
      return jsonErr(404, {'message': 'Workspace not found'});
    }

    await _repository.rename(id: id, name: name);
    return jsonOk({'success': true});
  }

  Future<Response> _delete(Request request, String id) async {
    final workspace = await _repository.getById(id);
    if (workspace == null || workspace.userId != request.userId) {
      return jsonErr(404, {'message': 'Workspace not found'});
    }
    if (workspace.isDefault) {
      return jsonErr(400, {'message': 'Cannot delete the default workspace'});
    }

    // Move songs to the default workspace before deleting.
    final defaultWs =
        await _repository.getDefaultByUserId(request.userId);
    if (defaultWs != null) {
      await _repository.reassignSongs(
        fromWorkspaceId: id,
        toWorkspaceId: defaultWs.id,
      );
    }

    await _repository.delete(id);
    return jsonOk({'success': true});
  }
}
