import 'package:flutter/material.dart';

const gmProgramNames = [
  'Acoustic Grand Piano', 'Bright Acoustic Piano', 'Electric Grand Piano',
  'Honky-tonk Piano', 'Electric Piano 1', 'Electric Piano 2', 'Harpsichord',
  'Clavinet', 'Celesta', 'Glockenspiel', 'Music Box', 'Vibraphone',
  'Marimba', 'Xylophone', 'Tubular Bells', 'Dulcimer', 'Drawbar Organ',
  'Percussive Organ', 'Rock Organ', 'Church Organ', 'Reed Organ',
  'Accordion', 'Harmonica', 'Tango Accordion', 'Nylon Guitar',
  'Steel Guitar', 'Jazz Guitar', 'Clean Electric Guitar',
  'Muted Electric Guitar', 'Overdriven Guitar', 'Distortion Guitar',
  'Guitar Harmonics', 'Acoustic Bass', 'Finger Bass', 'Pick Bass',
  'Fretless Bass', 'Slap Bass 1', 'Slap Bass 2', 'Synth Bass 1',
  'Synth Bass 2', 'Violin', 'Viola', 'Cello', 'Contrabass',
  'Tremolo Strings', 'Pizzicato Strings', 'Orchestral Harp', 'Timpani',
  'String Ensemble 1', 'String Ensemble 2', 'Synth Strings 1',
  'Synth Strings 2', 'Choir Aahs', 'Voice Oohs', 'Synth Choir',
  'Orchestra Hit', 'Trumpet', 'Trombone', 'Tuba', 'Muted Trumpet',
  'French Horn', 'Brass Section', 'Synth Brass 1', 'Synth Brass 2',
  'Soprano Sax', 'Alto Sax', 'Tenor Sax', 'Baritone Sax', 'Oboe',
  'English Horn', 'Bassoon', 'Clarinet', 'Piccolo', 'Flute', 'Recorder',
  'Pan Flute', 'Blown Bottle', 'Shakuhachi', 'Whistle', 'Ocarina',
  'Square Lead', 'Sawtooth Lead', 'Calliope Lead', 'Chiff Lead',
  'Charang Lead', 'Voice Lead', 'Fifths Lead', 'Bass + Lead',
  'New Age Pad', 'Warm Pad', 'Polysynth Pad', 'Choir Pad',
  'Bowed Pad', 'Metallic Pad', 'Halo Pad', 'Sweep Pad',
  'Rain FX', 'Soundtrack FX', 'Crystal FX', 'Atmosphere FX',
  'Brightness FX', 'Goblins FX', 'Echoes FX', 'Sci-Fi FX',
  'Sitar', 'Banjo', 'Shamisen', 'Koto', 'Kalimba', 'Bagpipe',
  'Fiddle', 'Shanai', 'Tinkle Bell', 'Agogo', 'Steel Drums',
  'Woodblock', 'Taiko Drum', 'Melodic Tom', 'Synth Drum',
  'Reverse Cymbal', 'Guitar Fret Noise', 'Breath Noise', 'Seashore',
  'Bird Tweet', 'Telephone Ring', 'Helicopter', 'Applause', 'Gunshot',
];

class InstrumentPicker extends StatelessWidget {
  final int? selectedProgram;
  final ValueChanged<int?> onChanged;
  final bool showAuto;

  const InstrumentPicker({
    super.key,
    this.selectedProgram,
    required this.onChanged,
    this.showAuto = true,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int?>(
      initialValue: selectedProgram,
      decoration: const InputDecoration(
        labelText: 'Instrument',
        isDense: true,
      ),
      isExpanded: true,
      items: [
        if (showAuto)
          const DropdownMenuItem<int?>(
            value: null,
            child: Text('Auto'),
          ),
        const DropdownMenuItem<int?>(
          value: -1,
          child: Text('Drums'),
        ),
        ...List.generate(128, (i) {
          return DropdownMenuItem<int?>(
            value: i,
            child: Text('$i: ${gmProgramNames[i]}'),
          );
        }),
      ],
      onChanged: onChanged,
    );
  }
}
