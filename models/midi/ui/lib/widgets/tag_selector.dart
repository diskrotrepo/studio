import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tags_provider.dart';
import '../theme/app_theme.dart';

class TagSelector extends ConsumerWidget {
  final Set<String> selectedTags;
  final ValueChanged<Set<String>> onChanged;

  const TagSelector({
    super.key,
    required this.selectedTags,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsProvider);
    final theme = Theme.of(context);

    return tagsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(color: AppColors.controlBlue)),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Could not load tags',
          style: TextStyle(color: theme.colorScheme.error),
        ),
      ),
      data: (tags) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tags.genres.isNotEmpty)
            _TagGroup(
              label: 'Genres',
              tags: tags.genres,
              selected: selectedTags,
              onChanged: onChanged,
            ),
          if (tags.moods.isNotEmpty)
            _TagGroup(
              label: 'Moods',
              tags: tags.moods,
              selected: selectedTags,
              onChanged: onChanged,
            ),
          if (tags.tempos.isNotEmpty)
            _TagGroup(
              label: 'Tempos',
              tags: tags.tempos,
              selected: selectedTags,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}

class _TagGroup extends StatelessWidget {
  final String label;
  final List<String> tags;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const _TagGroup({
    required this.label,
    required this.tags,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: tags.map((tag) {
              final isSelected = selected.contains(tag);
              return FilterChip(
                label: Text(tag.replaceAll('_', ' ')),
                selected: isSelected,
                selectedColor: AppColors.brand.withValues(alpha: 0.3),
                backgroundColor: AppColors.surfaceHigh,
                side: BorderSide(
                  color: isSelected ? AppColors.brand : AppColors.border,
                ),
                onSelected: (_) {
                  final updated = Set<String>.from(selected);
                  if (isSelected) {
                    updated.remove(tag);
                  } else {
                    updated.add(tag);
                  }
                  onChanged(updated);
                },
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
