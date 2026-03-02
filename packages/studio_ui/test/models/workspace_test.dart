import 'package:flutter_test/flutter_test.dart';
import 'package:studio_ui/models/workspace.dart';

void main() {
  group('Workspace.fromJson', () {
    test('parses all fields', () {
      final w = Workspace.fromJson({
        'id': 'w-1',
        'name': 'My Workspace',
        'is_default': true,
        'created_at': '2024-01-15T10:30:00Z',
      });
      expect(w.id, 'w-1');
      expect(w.name, 'My Workspace');
      expect(w.isDefault, true);
      expect(w.createdAt, isNotNull);
      expect(w.createdAt!.year, 2024);
    });

    test('defaults isDefault to false', () {
      final w = Workspace.fromJson({
        'id': 'w-2',
        'name': 'Test',
      });
      expect(w.isDefault, false);
    });

    test('handles null created_at', () {
      final w = Workspace.fromJson({
        'id': 'w-3',
        'name': 'Test',
      });
      expect(w.createdAt, isNull);
    });

    test('handles invalid date string', () {
      final w = Workspace.fromJson({
        'id': 'w-4',
        'name': 'Test',
        'created_at': 'not-a-date',
      });
      expect(w.createdAt, isNull);
    });
  });

  group('Workspace.copyWith', () {
    test('copies with new name', () {
      final w = Workspace(id: 'w-1', name: 'Old', isDefault: false);
      final copy = w.copyWith(name: 'New');
      expect(copy.name, 'New');
      expect(copy.id, 'w-1');
      expect(copy.isDefault, false);
    });

    test('preserves fields when no arguments given', () {
      final w = Workspace(id: 'w-1', name: 'Keep', isDefault: true);
      final copy = w.copyWith();
      expect(copy.name, 'Keep');
      expect(copy.isDefault, true);
    });
  });
}
