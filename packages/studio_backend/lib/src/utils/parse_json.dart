import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';

Future<T> parseJsonRequestBody<T>(
  Request request,
  T Function(Map<String, dynamic>) fromJson,
) async {
  final body = await request.readAsString();
  final json = jsonDecode(body) as Map<String, dynamic>;
  return fromJson(json);
}

Future<T> parseJsonResponseBody<T>(
  http.Response response,
  T Function(Map<String, dynamic>) fromJson,
) async {
  final body = response.body;

  if (body.isEmpty) {
    throw Exception('Response body is empty');
  }

  try {
    final json = jsonDecode(body) as Map<String, dynamic>;
    return fromJson(json);
  } catch (e) {
    throw Exception('Failed to decode JSON: $e');
  }
}
