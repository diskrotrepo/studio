import 'package:flutter_test/flutter_test.dart';
import 'package:studio_ui/models/model_capabilities.dart';

void main() {
  group('ModelCapabilities.fromJson', () {
    test('parses all fields', () {
      final mc = ModelCapabilities.fromJson({
        'model': 'ace-step',
        'enabled': true,
        'task_types': ['generate', 'infill'],
        'parameters': ['temperature', 'seed'],
        'features': {'lyrics': true, 'negative_prompt': false},
      });
      expect(mc.model, 'ace-step');
      expect(mc.enabled, true);
      expect(mc.taskTypes, ['generate', 'infill']);
      expect(mc.parameters, ['temperature', 'seed']);
      expect(mc.features, {'lyrics': true, 'negative_prompt': false});
    });

    test('defaults enabled to true', () {
      final mc = ModelCapabilities.fromJson({
        'model': 'test',
        'task_types': <String>[],
        'parameters': <String>[],
        'features': <String, dynamic>{},
      });
      expect(mc.enabled, true);
    });
  });

  group('ModelCapabilities.supportsTaskType', () {
    final mc = ModelCapabilities(
      model: 'test',
      enabled: true,
      taskTypes: ['generate', 'cover'],
      parameters: [],
      features: {},
    );

    test('returns true for supported type', () {
      expect(mc.supportsTaskType('generate'), true);
    });

    test('returns false for unsupported type', () {
      expect(mc.supportsTaskType('infill'), false);
    });
  });

  group('ModelCapabilities.supportsParameter', () {
    final mc = ModelCapabilities(
      model: 'test',
      enabled: true,
      taskTypes: [],
      parameters: ['temperature', 'seed'],
      features: {},
    );

    test('returns true for supported parameter', () {
      expect(mc.supportsParameter('temperature'), true);
    });

    test('returns false for unsupported parameter', () {
      expect(mc.supportsParameter('batch_size'), false);
    });
  });

  group('ModelCapabilities.hasFeature', () {
    final mc = ModelCapabilities(
      model: 'test',
      enabled: true,
      taskTypes: [],
      parameters: [],
      features: {'lyrics': true, 'lora': false},
    );

    test('returns true for enabled feature', () {
      expect(mc.hasFeature('lyrics'), true);
    });

    test('returns false for disabled feature', () {
      expect(mc.hasFeature('lora'), false);
    });

    test('returns false for unknown feature', () {
      expect(mc.hasFeature('unknown'), false);
    });
  });
}
