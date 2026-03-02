import 'package:studio_backend/src/peers/peer_repository.dart';
import 'package:studio_backend/src/utils/shelf_helper.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class PeerService {
  PeerService({required PeerRepository repository})
      : _repository = repository;

  final PeerRepository _repository;

  Router get router {
    final r = Router();
    r.get('/', _getAll);
    r.put('/<id>/block', _block);
    r.put('/<id>/unblock', _unblock);
    return r;
  }

  Future<Response> _getAll(Request request) async {
    final peers = await _repository.getAll();
    final data = peers
        .map((p) => {
              'id': p.id,
              'public_key': p.publicKey,
              'first_seen_at': p.firstSeenAt.dateTime.toIso8601String(),
              'last_seen_at': p.lastSeenAt.dateTime.toIso8601String(),
              'request_count': p.requestCount,
              'blocked': p.blocked,
            })
        .toList();
    return jsonOk({'data': data});
  }

  Future<Response> _block(Request request, String id) async {
    await _repository.setBlocked(id, blocked: true);
    return jsonOk({'success': true});
  }

  Future<Response> _unblock(Request request, String id) async {
    await _repository.setBlocked(id, blocked: false);
    return jsonOk({'success': true});
  }
}
