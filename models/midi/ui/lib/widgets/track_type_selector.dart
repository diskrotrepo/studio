import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TrackTypeSelector extends StatelessWidget {
  final List<String> trackTypes;
  final ValueChanged<List<String>> onChanged;

  static const availableTypes = [
    'melody',
    'bass',
    'chords',
    'drums',
    'pad',
    'lead',
    'strings',
    'other',
  ];

  const TrackTypeSelector({
    super.key,
    required this.trackTypes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Track Types',
          style: theme.textTheme.labelLarge?.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(trackTypes.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  'Track ${index + 1}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: trackTypes[index],
                    decoration: const InputDecoration(isDense: true),
                    items: availableTypes.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        final updated = List<String>.from(trackTypes);
                        updated[index] = value;
                        onChanged(updated);
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class SingleTrackTypeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const SingleTrackTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'Track Type',
        isDense: true,
      ),
      items: TrackTypeSelector.availableTypes.map((type) {
        return DropdownMenuItem(
          value: type,
          child: Text(type),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}
