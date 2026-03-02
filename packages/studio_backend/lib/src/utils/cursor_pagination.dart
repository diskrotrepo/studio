import 'dart:convert';

import 'package:drift/drift.dart';

/// Represents a pagination cursor containing timestamp and ID for stable ordering
class PaginationCursor {
  const PaginationCursor({required this.timestamp, required this.id});

  final DateTime timestamp;
  final String id;

  @override
  String toString() => 'PaginationCursor(timestamp: $timestamp, id: $id)';
}

/// Encodes a cursor from timestamp and ID into a base64 string
///
/// Returns null if either timestamp or ID is null.
/// Format: base64("timestamp_iso8601|id")
///
/// Example:
/// ```dart
/// final cursor = encodeCursor(DateTime.now(), 'abc-123');
/// // Returns: "MjAyNC0wMS0yNVQxMDozMDowMC4wMDBafGFiYy0xMjM="
/// ```
String? encodeCursor(DateTime? timestamp, String? id) {
  if (timestamp == null || id == null) return null;

  final cursorString = '${timestamp.toIso8601String()}|$id';
  return base64Url.encode(utf8.encode(cursorString));
}

/// Decodes a base64 cursor string into a PaginationCursor
///
/// Returns null if cursorString is null or empty.
/// Throws [FormatException] if cursor format is invalid.
///
/// Example:
/// ```dart
/// final cursor = decodeCursor('MjAyNC0wMS0yNVQxMDozMDowMC4wMDBafGFiYy0xMjM=');
/// // Returns: PaginationCursor(timestamp: 2024-01-25T10:30:00.000Z, id: 'abc-123')
/// ```
PaginationCursor? decodeCursor(String? cursorString) {
  if (cursorString == null || cursorString.isEmpty) return null;

  try {
    final decoded = utf8.decode(base64Url.decode(cursorString));
    final parts = decoded.split('|');

    if (parts.length != 2) {
      throw const FormatException(
        'Invalid cursor format: expected "timestamp|id"',
      );
    }

    final timestamp = DateTime.parse(parts[0]);
    final id = parts[1];

    if (id.isEmpty) {
      throw const FormatException('Invalid cursor format: id cannot be empty');
    }

    return PaginationCursor(timestamp: timestamp, id: id);
  } on FormatException {
    rethrow;
  } catch (e) {
    throw FormatException('Invalid cursor format: $e');
  }
}

/// Builds a Drift where clause for cursor-based pagination
///
/// For descending order (most common case):
/// - Returns: `(timestamp < cursor.timestamp) OR (timestamp = cursor.timestamp AND id < cursor.id)`
/// - This ensures we get all rows that come "after" the cursor in reverse chronological order
///
/// If cursor is null, returns a constant true expression (no filtering).
///
/// Pass the actual column objects from your table (not expressions) and the cursor.
/// IMPORTANT: Use table.column directly, not expressions, to ensure proper SQL generation in JOINs.
///
/// Example usage:
/// ```dart
/// final query = database.select(database.status)
///   ..where(
///     database.status.applicationId.equals(appId) &
///     buildCursorWhereClause(database.status.createdAt, database.status.id, cursor)
///   )
///   ..orderBy([
///     OrderingTerm(expression: database.status.createdAt, mode: OrderingMode.desc),
///     OrderingTerm(expression: database.status.id, mode: OrderingMode.desc),
///   ])
///   ..limit(limit + 1);
/// ```
Expression<bool> buildCursorWhereClause<T extends Object>(
  GeneratedColumn<T> timestampColumn,
  GeneratedColumn<String> idColumn,
  PaginationCursor? cursor, {
  bool descending = true,
}) {
  if (cursor == null) {
    return const Constant(true);
  }

  final timestampStr = cursor.timestamp.toIso8601String();
  final idStr = cursor.id.replaceAll("'", "''"); // Escape single quotes

  return _CursorComparisonExpression(
    timestampColumn: timestampColumn,
    idColumn: idColumn,
    cursorTimestamp: timestampStr,
    cursorId: idStr,
    descending: descending,
  );
}

/// Custom expression for cursor-based pagination that properly handles table qualification
class _CursorComparisonExpression extends Expression<bool> {
  _CursorComparisonExpression({
    required this.timestampColumn,
    required this.idColumn,
    required this.cursorTimestamp,
    required this.cursorId,
    this.descending = true,
  });

  final GeneratedColumn timestampColumn;
  final GeneratedColumn<String> idColumn;
  final String cursorTimestamp;
  final String cursorId;
  final bool descending;

  @override
  void writeInto(GenerationContext context) {
    final op = descending ? '<' : '>';
    context.buffer.write('(');
    timestampColumn.writeInto(context);
    context.buffer.write(" $op TIMESTAMP '$cursorTimestamp' OR (");
    timestampColumn.writeInto(context);
    context.buffer.write(" = TIMESTAMP '$cursorTimestamp' AND ");
    idColumn.writeInto(context);
    context.buffer.write(" $op '$cursorId'))");
  }

  @override
  int get hashCode =>
      Object.hash(timestampColumn, idColumn, cursorTimestamp, cursorId, descending);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CursorComparisonExpression &&
          other.timestampColumn == timestampColumn &&
          other.idColumn == idColumn &&
          other.cursorTimestamp == cursorTimestamp &&
          other.cursorId == cursorId &&
          other.descending == descending;

  @override
  Precedence get precedence => Precedence.comparisonEq;
}
