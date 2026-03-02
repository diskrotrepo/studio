import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/picked_file.dart';

/// Holds a MIDI file to pre-load into the Edit screen tabs.
/// Set by history card "Edit" action, consumed and cleared by edit tabs.
final editFileProvider = StateProvider<PickedFile?>((ref) => null);
