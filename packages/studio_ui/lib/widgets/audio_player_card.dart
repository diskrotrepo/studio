import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/now_playing.dart';
import '../models/generation_result.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/file_saver.dart';

class AudioPlayerCard extends StatefulWidget {
  const AudioPlayerCard({
    super.key,
    required this.audioFile,
    required this.taskId,
    required this.index,
    required this.onPlay,
  });

  final AudioFile audioFile;
  final String taskId;
  final int index;
  final VoidCallback onPlay;

  @override
  State<AudioPlayerCard> createState() => _AudioPlayerCardState();
}

class _AudioPlayerCardState extends State<AudioPlayerCard> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final apiClient = context.read<ApiClient>();
      final url = apiClient.songDownloadUrl(widget.taskId);
      final bytes = await apiClient.downloadAudioBytes(url);
      if (!mounted) return;
      final filename = widget.audioFile.filename.endsWith('.mp3')
          ? widget.audioFile.filename
          : '${widget.audioFile.filename}.mp3';
      await saveFile(bytes, filename);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.accent,
            content: Text('Download complete'),
          ),
        );
      }
    } catch (_) {}
    if (mounted) setState(() => _downloading = false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlayingTrack?>(
      valueListenable: NowPlaying.instance.track,
      builder: (context, currentTrack, _) {
        final isPlaying = currentTrack?.audioUrl == widget.audioFile.url;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isPlaying ? AppColors.controlPink : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.equalizer : Icons.play_arrow,
                  color: AppColors.controlPink,
                ),
                iconSize: 20,
                onPressed: widget.onPlay,
                tooltip: isPlaying ? 'Now Playing' : 'Play',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Track ${widget.index + 1}',
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.audioFile.filename,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _downloading
                  ? const SizedBox(
                      width: 36,
                      height: 36,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.controlPink,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.download,
                        color: AppColors.controlPink,
                        size: 20,
                      ),
                      tooltip: 'Download',
                      onPressed: _download,
                    ),
            ],
          ),
        );
      },
    );
  }
}
