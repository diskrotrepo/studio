import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/models_provider.dart';
import '../theme/app_theme.dart';

class ModelSelector extends ConsumerWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const ModelSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsAsync = ref.watch(modelsProvider);
    final theme = Theme.of(context);

    return modelsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (models) {
        if (models.isEmpty) return const SizedBox.shrink();

        final effective = models.contains(selected) ? selected : models.first;

        return Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(
                'Model',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
            Expanded(
              child: DropdownButton<String>(
                value: effective,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: models
                    .map((name) => DropdownMenuItem(
                          value: name,
                          child: Text(name),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Refresh models',
              color: AppColors.textMuted,
              onPressed: () => ref.invalidate(modelsProvider),
            ),
          ],
        );
      },
    );
  }
}
