import 'dart:convert';
import 'dart:io';

import 'package:studio_backend/src/utils/shelf_helper.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class BrowseService {
  BrowseService({List<String>? allowedRoots})
      : _allowedRoots = allowedRoots ?? _defaultRoots();

  final List<String> _allowedRoots;

  static List<String> _defaultRoots() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;
    return [home];
  }

  Router get router {
    final r = Router();
    r.post('/', _browse);
    return r;
  }

  Future<Response> _browse(Request request) async {
    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;

    final rawPath = (body['path'] as String?)?.trim() ?? '.';
    final fileExtensions = (body['file_extensions'] as List<dynamic>?)
        ?.cast<String>();

    final dir = Directory(rawPath);
    if (!dir.existsSync()) {
      return jsonErr(400, {'message': 'Directory not found'});
    }

    final resolved = dir.resolveSymbolicLinksSync();
    final resolvedDir = Directory(resolved);

    // Verify resolved path is within an allowed root.
    final isAllowed = _allowedRoots.any((root) {
      try {
        final resolvedRoot = Directory(root).resolveSymbolicLinksSync();
        return resolved == resolvedRoot ||
            resolved.startsWith('$resolvedRoot${Platform.pathSeparator}');
      } catch (_) {
        return false;
      }
    });
    if (!isAllowed) {
      return jsonErr(403, {'message': 'Access denied'});
    }

    if (!resolvedDir.existsSync()) {
      return jsonErr(400, {'message': 'Directory not found'});
    }

    final extSet = fileExtensions != null
        ? {
            for (final e in fileExtensions)
              e.startsWith('.') ? e.toLowerCase() : '.$e'.toLowerCase(),
          }
        : <String>{};

    final directories = <String>[];
    final files = <String>[];

    try {
      final entries = resolvedDir.listSync()
        ..sort((a, b) =>
            a.path.split(Platform.pathSeparator).last.toLowerCase().compareTo(
                  b.path.split(Platform.pathSeparator).last.toLowerCase(),
                ));

      for (final entry in entries) {
        final name = entry.path.split(Platform.pathSeparator).last;
        if (name.startsWith('.')) continue;

        if (entry is Directory) {
          directories.add(name);
        } else if (extSet.isNotEmpty && entry is File) {
          final dot = name.lastIndexOf('.');
          if (dot >= 0) {
            final ext = name.substring(dot).toLowerCase();
            if (extSet.contains(ext)) files.add(name);
          }
        }
      }
    } on FileSystemException {
      return jsonErr(403, {'message': 'Permission denied'});
    }

    final parent = resolvedDir.parent.path;
    final result = <String, dynamic>{
      'path': resolved,
      if (parent != resolved) 'parent': parent,
      'directories': directories,
    };
    if (extSet.isNotEmpty) result['files'] = files;

    return jsonOk(result);
  }
}
