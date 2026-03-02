import 'package:flutter/material.dart';

import '../models/genre_data.dart';

class GenreChip extends StatelessWidget {
  const GenreChip({
    super.key,
    required this.name,
    required this.genre,
    required this.onRemove,
  });

  final String name;
  final MajorGenre genre;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final color = genre.color;
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 2, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              name,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: onRemove,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Icon(
                Icons.close,
                size: 14,
                color: color.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
