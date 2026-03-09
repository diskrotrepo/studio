import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

const _kTracks = 16;
const _kSteps = 32;
const _kCellSize = 28.0;
const _kCellGap = 2.0;
const _kLabelWidth = 80.0;
const _kClearBtnWidth = 28.0;
const _kHeaderHeight = 24.0;

const _kTrackNames = [
  'Kick',
  'Snare',
  'Hi-Hat',
  'Open HH',
  'Tom 1',
  'Tom 2',
  'Crash',
  'Ride',
  'Clap',
  'Rim',
  'Cowbell',
  'Shaker',
  'Perc 1',
  'Perc 2',
  'Bass',
  'Synth',
];

const _accent = Color(0xFFFFA726);

class SequencerPage extends StatefulWidget {
  const SequencerPage({super.key});

  @override
  State<SequencerPage> createState() => _SequencerPageState();
}

class _SequencerPageState extends State<SequencerPage> {
  late List<List<bool>> _grid;
  final _bpmController = TextEditingController(text: '120');

  @override
  void initState() {
    super.initState();
    _grid = List.generate(_kTracks, (_) => List.filled(_kSteps, false));
  }

  @override
  void dispose() {
    _bpmController.dispose();
    super.dispose();
  }

  void _toggleStep(int track, int step) {
    setState(() => _grid[track][step] = !_grid[track][step]);
  }

  void _clearAll() {
    setState(() {
      for (var t = 0; t < _kTracks; t++) {
        for (var s = 0; s < _kSteps; s++) {
          _grid[t][s] = false;
        }
      }
    });
  }

  void _clearTrack(int track) {
    setState(() {
      for (var s = 0; s < _kSteps; s++) {
        _grid[track][s] = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = Responsive.of(constraints.maxWidth);
        final padding = Responsive.pagePadding(screen);

        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildToolbar(),
              const SizedBox(height: 16),
              Expanded(child: _buildGrid()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        const Text(
          'Sequencer',
          style: TextStyle(
            color: AppColors.settingsHeading,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        const Text(
          'BPM',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          height: 32,
          child: TextField(
            controller: _bpmController,
            style: const TextStyle(color: AppColors.text, fontSize: 13),
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _BpmFormatter(),
            ],
            decoration: const InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 16),
        TextButton(
          onPressed: _clearAll,
          child: const Text(
            'Clear All',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fixed track labels + clear buttons
        SizedBox(
          width: _kLabelWidth + _kClearBtnWidth,
          child: Column(
            children: [
              SizedBox(height: _kHeaderHeight + _kCellGap),
              for (var t = 0; t < _kTracks; t++)
                SizedBox(
                  height: _kCellSize + _kCellGap,
                  child: Row(
                    children: [
                      SizedBox(
                        width: _kLabelWidth,
                        child: Text(
                          _kTrackNames[t],
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _ClearTrackButton(onTap: () => _clearTrack(t)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        // Scrollable step grid
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step number header
                SizedBox(
                  height: _kHeaderHeight,
                  child: Row(
                    children: [
                      for (var s = 0; s < _kSteps; s++)
                        SizedBox(
                          width: _kCellSize + _kCellGap,
                          child: Center(
                            child: Text(
                              '${s + 1}',
                              style: TextStyle(
                                color: (s % 4 == 0)
                                    ? AppColors.textMuted
                                    : AppColors.textMuted
                                        .withValues(alpha: 0.4),
                                fontSize: 9,
                                fontWeight: (s % 4 == 0)
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: _kCellGap),
                // Track rows
                for (var t = 0; t < _kTracks; t++)
                  Padding(
                    padding: EdgeInsets.only(bottom: _kCellGap),
                    child: Row(
                      children: [
                        for (var s = 0; s < _kSteps; s++)
                          _StepCell(
                            active: _grid[t][s],
                            beatGroup: (s ~/ 4) % 2,
                            onTap: () => _toggleStep(t, s),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StepCell extends StatefulWidget {
  const _StepCell({
    required this.active,
    required this.beatGroup,
    required this.onTap,
  });

  final bool active;
  final int beatGroup; // 0 or 1 for alternating groups
  final VoidCallback onTap;

  @override
  State<_StepCell> createState() => _StepCellState();
}

class _StepCellState extends State<_StepCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final inactiveBg = widget.beatGroup == 0
        ? AppColors.surface
        : AppColors.surfaceHigh;

    final bg = widget.active
        ? _accent.withValues(alpha: 0.85)
        : _hovered
            ? _accent.withValues(alpha: 0.15)
            : inactiveBg;

    final border = widget.active
        ? _accent
        : AppColors.border;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: _kCellSize,
          height: _kCellSize,
          margin: EdgeInsets.only(right: _kCellGap),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border, width: 1),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

class _ClearTrackButton extends StatefulWidget {
  const _ClearTrackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ClearTrackButton> createState() => _ClearTrackButtonState();
}

class _ClearTrackButtonState extends State<_ClearTrackButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: _kClearBtnWidth,
          height: _kCellSize,
          child: Icon(
            Icons.clear,
            size: 14,
            color: _hovered
                ? AppColors.text
                : AppColors.textMuted.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _BpmFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final n = int.tryParse(newValue.text);
    if (n == null) return oldValue;
    if (n > 300) {
      return const TextEditingValue(
        text: '300',
        selection: TextSelection.collapsed(offset: 3),
      );
    }
    return newValue;
  }
}
