import 'dart:convert';

import 'package:studio_backend/src/audio/audio_generation_task_repository.dart';
import 'package:studio_backend/src/lyric_book/lyric_book_repository.dart';
import 'package:studio_backend/src/utils/shelf_helper.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class LyricBookService {
  LyricBookService({
    required LyricBookRepository repository,
    required AudioGenerationTaskRepository taskRepository,
  })  : _repository = repository,
        _taskRepository = taskRepository;

  final LyricBookRepository _repository;
  final AudioGenerationTaskRepository _taskRepository;

  Router get router {
    final r = Router();
    r.get('/', _getAll);
    r.post('/', _create);
    r.get('/search', _search);
    r.get('/<id>', _getById);
    r.patch('/<id>', _update);
    r.delete('/<id>', _delete);
    return r;
  }

  Future<Response> _getAll(Request request) async {
    final sheets = await _repository.getAllByUserId(request.userId);
    final data = sheets
        .map((s) => {
              'id': s.id,
              'title': s.title,
              'content': s.content,
              'created_at': s.createdAt.dateTime.toIso8601String(),
            })
        .toList();
    return jsonOk({'data': data});
  }

  Future<Response> _create(Request request) async {
    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final title = body['title'] as String? ?? '';
    final content = body['content'] as String? ?? '';

    final titleErr = validateMaxLength(title, 'title', maxLength: 500);
    if (titleErr != null) {
      return jsonErr(400, {'message': titleErr});
    }
    final contentErr =
        validateMaxLength(content, 'content', maxLength: 100000);
    if (contentErr != null) {
      return jsonErr(400, {'message': contentErr});
    }

    final sheet = await _repository.create(
      userId: request.userId,
      title: title,
      content: content,
    );

    return jsonOk({
      'id': sheet.id,
      'title': sheet.title,
      'content': sheet.content,
      'created_at': sheet.createdAt.dateTime.toIso8601String(),
    });
  }

  Future<Response> _getById(Request request, String id) async {
    final sheet = await _repository.getById(id);
    if (sheet == null || sheet.userId != request.userId) {
      return jsonErr(404, {'message': 'Lyric sheet not found'});
    }

    // Fetch linked songs.
    final songs = await _taskRepository.getSongsByLyricSheetId(
      lyricSheetId: id,
      userId: request.userId,
    );

    final songData = songs
        .map((s) => {
              'task_id': s.taskId,
              'title': s.title,
              'model': s.model,
              'created_at': s.createdAt.dateTime.toIso8601String(),
            })
        .toList();

    return jsonOk({
      'id': sheet.id,
      'title': sheet.title,
      'content': sheet.content,
      'created_at': sheet.createdAt.dateTime.toIso8601String(),
      'songs': songData,
    });
  }

  Future<Response> _update(Request request, String id) async {
    final sheet = await _repository.getById(id);
    if (sheet == null || sheet.userId != request.userId) {
      return jsonErr(404, {'message': 'Lyric sheet not found'});
    }

    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;

    final title = body['title'] as String?;
    final content = body['content'] as String?;

    final titleErr = validateMaxLength(title, 'title', maxLength: 500);
    if (titleErr != null) {
      return jsonErr(400, {'message': titleErr});
    }
    final contentErr =
        validateMaxLength(content, 'content', maxLength: 100000);
    if (contentErr != null) {
      return jsonErr(400, {'message': contentErr});
    }

    await _repository.update(
      id: id,
      title: title,
      content: content,
    );
    return jsonOk({'success': true});
  }

  Future<Response> _delete(Request request, String id) async {
    final sheet = await _repository.getById(id);
    if (sheet == null || sheet.userId != request.userId) {
      return jsonErr(404, {'message': 'Lyric sheet not found'});
    }

    // Unlink any songs referencing this sheet.
    await _taskRepository.clearLyricSheetId(lyricSheetId: id);

    await _repository.delete(id);
    return jsonOk({'success': true});
  }

  Future<Response> _search(Request request) async {
    final query = request.url.queryParameters['q'] ?? '';
    if (query.isEmpty) {
      return jsonErr(400, {'message': 'q parameter is required'});
    }

    final sheets = await _repository.search(
      userId: request.userId,
      query: query,
    );

    final data = sheets
        .map((s) => {
              'id': s.id,
              'title': s.title,
              'content': s.content,
              'created_at': s.createdAt.dateTime.toIso8601String(),
            })
        .toList();
    return jsonOk({'data': data});
  }
}
