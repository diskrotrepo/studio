import 'dart:convert';

import 'package:studio_backend/src/utils/cursor_pagination.dart';
import 'package:studio_backend/src/utils/exceptions.dart';
import 'package:shelf/shelf.dart';

Response jsonOk(Object body, {Map<String, String>? extraHeaders}) =>
    Response.ok(
      jsonEncode(body),
      headers: {
        'Content-Type': 'application/json',
        if (extraHeaders != null) ...extraHeaders,
      },
    );

Response jsonErr(
  int status,
  Object body, {
  Map<String, String>? extraHeaders,
}) => Response(
  status,
  body: jsonEncode(body),
  headers: {
    'Content-Type': 'application/json',
    if (extraHeaders != null) ...extraHeaders,
  },
);

String? extractContentType(Map<String, String> headers) =>
    headers['content-type'] ?? headers['Content-Type'];

String? dispositionParam(String? header, String param) {
  if (header == null) return null;
  for (final part in header.split(';')) {
    final kv = part.trim().split('=');
    if (kv.length == 2 && kv[0].toLowerCase() == param.toLowerCase()) {
      final raw = kv[1].trim();
      return raw.length >= 2 && raw.startsWith('"') && raw.endsWith('"')
          ? raw.substring(1, raw.length - 1)
          : raw;
    }
  }
  return null;
}

extension RequestAuth on Request {
  String get userId => headers['Diskrot-User-Id'] ?? '1';
  String get projectId => 'diskrot-studio';
  Map<String, dynamic> get claims => context['claims']! as Map<String, dynamic>;
  bool get isAnonymous => false;
  bool get isAdmin =>
      !headers.containsKey('X-Signature') &&
      !headers.containsKey('X-Public-Key');
  String get applicationId => headers['Diskrot-Project-Id'] ?? projectId;
}

String? validateMaxLength(String? value, String field, {int maxLength = 10000}) {
  if (value != null && value.length > maxLength) {
    return '$field exceeds maximum length of $maxLength characters';
  }
  return null;
}

int parseLimit(
  Map<String, String> query, {
  int defaultValue = 25,
  int max = 100,
}) {
  final value = int.tryParse(query['limit'] ?? '') ?? defaultValue;
  return value.clamp(1, max);
}

int parseOffset(
  Map<String, String> query, {
  int defaultValue = 0,
  int max = 10000,
}) {
  final value = int.tryParse(query['offset'] ?? '') ?? defaultValue;
  return value.clamp(0, max);
}

PaginationCursor? parseCursor(Map<String, String> query) {
  final cursorString = query['cursor'];
  if (cursorString == null || cursorString.isEmpty) return null;

  try {
    return decodeCursor(cursorString);
  } catch (e) {
    throw const InvalidCursorException('Invalid cursor format');
  }
}
