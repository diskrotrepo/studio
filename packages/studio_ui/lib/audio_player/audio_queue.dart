import 'package:flutter/material.dart';

import '../application/now_playing.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class QueueSheet extends StatelessWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final now = NowPlaying.instance;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: .3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.queueTitle,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    now.clearQueue();
                    Navigator.of(context).maybePop();
                  },
                  icon: const Icon(
                    Icons.clear_all,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                  label: Text(
                    s.buttonClear,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<List<PlayingTrack>>(
              valueListenable: now.queue,
              builder: (context, queue, _) {
                return ValueListenableBuilder<int>(
                  valueListenable: now.index,
                  builder: (context, idx, _) {
                    if (queue.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.queue_music,
                              color: AppColors.textMuted,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              s.queueEmpty,
                              style: const TextStyle(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      );
                    }

                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 420),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: queue.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (context, i) {
                          final t = queue[i];
                          final isCurrent = i == idx;
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            minLeadingWidth: 0,
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceHigh,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Icon(
                                Icons.music_note,
                                color: isCurrent
                                    ? AppColors.controlPink
                                    : AppColors.textMuted,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.text,
                                fontWeight: isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              Uri.tryParse(
                                    t.audioUrl,
                                  )?.pathSegments.lastOrNull ??
                                  t.audioUrl,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isCurrent)
                                  const Icon(
                                    Icons.equalizer,
                                    color: AppColors.controlPink,
                                    size: 18,
                                  ),
                                IconButton(
                                  tooltip: s.tooltipRemove,
                                  icon: const Icon(
                                    Icons.close,
                                    color: AppColors.textMuted,
                                  ),
                                  onPressed: () {
                                    NowPlaying.instance.removeAt(i);
                                  },
                                ),
                              ],
                            ),
                            onTap: () {
                              NowPlaying.instance.playIndex(i);
                              Navigator.of(context).maybePop();
                            },
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
