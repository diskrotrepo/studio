import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_provider.dart';
import '../providers/history_provider.dart';
import '../theme/app_theme.dart';
import 'audio_scrubber.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTaskId = ref.watch(currentlyPlayingTaskProvider);
    if (currentTaskId == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final history = ref.watch(historyProvider);
    final task = history.where((t) => t.taskId == currentTaskId).firstOrNull;

    final playerState = ref.watch(playerStateProvider);
    final position = ref.watch(playerPositionProvider);
    final duration = ref.watch(playerDurationProvider);

    final isPlaying = playerState.whenOrNull(data: (s) => s.playing) ?? false;
    final pos = position.valueOrNull ?? Duration.zero;
    final dur = duration.valueOrNull ?? Duration.zero;

    return Container(
      height: 76,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        children: [
          const AudioScrubber(compact: true),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.music_note,
                    color: AppColors.controlBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task != null
                              ? _buildTitle(task.generationType, task.tagsUsed)
                              : 'Playing...',
                          style: theme.textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${_formatDuration(pos)} / ${_formatDuration(dur)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white),
                    onPressed: () async {
                      final audio = ref.read(audioServiceProvider);
                      if (isPlaying) {
                        await audio.pause();
                      } else {
                        await audio.play();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.white),
                    onPressed: () async {
                      await ref.read(audioServiceProvider).stop();
                      ref.read(currentlyPlayingTaskProvider.notifier).state = null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildTitle(String type, String? tags) {
    final label = switch (type) {
      'single' => 'Single Track',
      'multitrack' => 'Multi-Track',
      'add-track' => 'Add Track',
      'replace-track' => 'Replace Track',
      _ => type,
    };
    if (tags != null && tags.isNotEmpty) {
      return '$label - $tags';
    }
    return label;
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
