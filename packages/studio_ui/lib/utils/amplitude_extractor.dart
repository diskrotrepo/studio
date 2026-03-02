import 'dart:math' as math;
import 'dart:typed_data';

/// Extract [count] normalized RMS amplitude values (0.0–1.0) from audio
/// [bytes].
///
/// Tries, in order: WAV PCM decode → MP3 frame energy → raw byte std-dev.
List<double> extractAmplitudes(Uint8List bytes, int count) {
  if (bytes.isEmpty || count <= 0) return List.filled(count, 0.0);

  final pcm = _tryDecodeWav(bytes);
  if (pcm != null) return _rmsFromSamples(pcm, count);

  final mp3 = _tryMp3FrameEnergy(bytes);
  if (mp3 != null) return _resample(mp3, count);

  return _stdDevChunks(bytes, 0, bytes.length, count);
}

// ── WAV ──────────────────────────────────────────────────────────────────────

Float64List? _tryDecodeWav(Uint8List bytes) {
  if (bytes.length < 44) return null;
  if (bytes[0] != 0x52 || bytes[1] != 0x49 ||
      bytes[2] != 0x46 || bytes[3] != 0x46) {
    return null;
  }
  if (bytes[8] != 0x57 || bytes[9] != 0x41 ||
      bytes[10] != 0x56 || bytes[11] != 0x45) {
    return null;
  }

  final bd = ByteData.sublistView(bytes);
  int offset = 12;
  int channels = 0, bitsPerSample = 0, dataStart = -1, dataSize = 0;

  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final chunkSize = bd.getUint32(offset + 4, Endian.little);
    offset += 8;

    if (id == 'fmt ') {
      if (offset + 16 > bytes.length) return null;
      if (bd.getUint16(offset, Endian.little) != 1) return null; // PCM only
      channels = bd.getUint16(offset + 2, Endian.little);
      bitsPerSample = bd.getUint16(offset + 14, Endian.little);
    } else if (id == 'data') {
      dataStart = offset;
      dataSize = chunkSize;
      break;
    }

    offset += chunkSize;
    if (chunkSize.isOdd) offset++;
  }

  if (dataStart < 0 || channels == 0 || bitsPerSample == 0) return null;
  final dataEnd = math.min(dataStart + dataSize, bytes.length);

  if (bitsPerSample == 16) {
    final bps = 2 * channels;
    final n = (dataEnd - dataStart) ~/ bps;
    if (n == 0) return null;
    final mono = Float64List(n);
    int pos = dataStart;
    for (int i = 0; i < n; i++) {
      double sum = 0;
      for (int c = 0; c < channels; c++) {
        sum += bd.getInt16(pos, Endian.little) / 32768.0;
        pos += 2;
      }
      mono[i] = sum / channels;
    }
    return mono;
  }

  if (bitsPerSample == 8) {
    final n = (dataEnd - dataStart) ~/ channels;
    if (n == 0) return null;
    final mono = Float64List(n);
    int pos = dataStart;
    for (int i = 0; i < n; i++) {
      double sum = 0;
      for (int c = 0; c < channels; c++) {
        sum += (bytes[pos] - 128) / 128.0;
        pos++;
      }
      mono[i] = sum / channels;
    }
    return mono;
  }

  return null;
}

// ── MP3 frame energy ─────────────────────────────────────────────────────────

/// MPEG1 Layer3 bitrate table (index 0-15, kbps).
const _mp1L3Bitrates = [
  0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0
];

/// MPEG2/2.5 Layer3 bitrate table.
const _mp2L3Bitrates = [
  0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0
];

/// MPEG1 sample rates.
const _mp1SampleRates = [44100, 48000, 32000];

/// MPEG2 sample rates.
const _mp2SampleRates = [22050, 24000, 16000];

/// MPEG2.5 sample rates.
const _mp25SampleRates = [11025, 12000, 8000];

/// Parse MP3 frames and compute per-frame energy (byte standard deviation).
/// Returns a list of normalized energies (one per frame), or null if the data
/// doesn't look like MP3.
List<double>? _tryMp3FrameEnergy(Uint8List bytes) {
  int offset = _skipId3v2(bytes);

  final energies = <double>[];

  while (offset + 4 < bytes.length) {
    // Sync word: 11 set bits.
    if (bytes[offset] != 0xFF || (bytes[offset + 1] & 0xE0) != 0xE0) {
      offset++;
      continue;
    }

    final h1 = bytes[offset + 1];
    final h2 = bytes[offset + 2];

    final version = (h1 >> 3) & 0x03; // 0=2.5, 2=2, 3=1
    final layer = (h1 >> 1) & 0x03; // 1=L3
    final brIdx = (h2 >> 4) & 0x0F;
    final srIdx = (h2 >> 2) & 0x03;
    final padding = (h2 >> 1) & 0x01;

    if (layer != 1 || brIdx == 0 || brIdx == 15 || srIdx > 2) {
      offset++;
      continue;
    }

    int bitrate, sampleRate, samplesPerFrame;

    if (version == 3) {
      // MPEG1
      bitrate = _mp1L3Bitrates[brIdx] * 1000;
      sampleRate = _mp1SampleRates[srIdx];
      samplesPerFrame = 1152;
    } else if (version == 2 || version == 0) {
      // MPEG2 / MPEG2.5
      bitrate = _mp2L3Bitrates[brIdx] * 1000;
      sampleRate =
          version == 2 ? _mp2SampleRates[srIdx] : _mp25SampleRates[srIdx];
      samplesPerFrame = 576;
    } else {
      offset++;
      continue;
    }

    if (bitrate == 0 || sampleRate == 0) {
      offset++;
      continue;
    }

    final frameSize =
        (samplesPerFrame * bitrate) ~/ (8 * sampleRate) + padding;
    if (frameSize < 4 || offset + frameSize > bytes.length) break;

    // Per-frame energy: standard deviation of payload bytes.
    final payloadStart = offset + 4;
    final payloadEnd = offset + frameSize;
    final payloadLen = payloadEnd - payloadStart;

    if (payloadLen > 0) {
      double sum = 0;
      for (int i = payloadStart; i < payloadEnd; i++) {
        sum += bytes[i];
      }
      final mean = sum / payloadLen;

      double varSum = 0;
      for (int i = payloadStart; i < payloadEnd; i++) {
        final d = bytes[i] - mean;
        varSum += d * d;
      }
      energies.add(math.sqrt(varSum / payloadLen));
    }

    offset += frameSize;
  }

  // Need at least some frames to consider this valid MP3.
  if (energies.length < 20) return null;

  // Normalize.
  double peak = 0;
  for (final e in energies) {
    if (e > peak) peak = e;
  }
  if (peak > 0) {
    for (int i = 0; i < energies.length; i++) {
      energies[i] /= peak;
    }
  }

  return energies;
}

/// Skip ID3v2 tag at the start of the file.
int _skipId3v2(Uint8List bytes) {
  if (bytes.length > 10 &&
      bytes[0] == 0x49 && // I
      bytes[1] == 0x44 && // D
      bytes[2] == 0x33) {
    // 3
    final size = ((bytes[6] & 0x7F) << 21) |
        ((bytes[7] & 0x7F) << 14) |
        ((bytes[8] & 0x7F) << 7) |
        (bytes[9] & 0x7F);
    return 10 + size;
  }
  return 0;
}

// ── Resampling / RMS helpers ─────────────────────────────────────────────────

/// Resample [source] (arbitrary length) into exactly [count] bins via linear
/// interpolation.
List<double> _resample(List<double> source, int count) {
  if (source.isEmpty) return List.filled(count, 0.0);
  if (source.length == count) return List<double>.from(source);

  final out = List<double>.filled(count, 0.0);
  final ratio = (source.length - 1) / (count - 1).clamp(1, count);
  for (int i = 0; i < count; i++) {
    final pos = i * ratio;
    final lo = pos.floor().clamp(0, source.length - 1);
    final hi = (lo + 1).clamp(0, source.length - 1);
    final frac = pos - lo;
    out[i] = source[lo] * (1 - frac) + source[hi] * frac;
  }
  return out;
}

/// Compute [count] RMS bins from decoded float samples.
List<double> _rmsFromSamples(Float64List samples, int count) {
  final n = samples.length;
  final chunkSize = math.max(1, n ~/ count);
  final amps = List<double>.filled(count, 0.0);
  double peak = 0;

  for (int i = 0; i < count; i++) {
    final start = i * chunkSize;
    final end = math.min(start + chunkSize, n);
    if (start >= n) break;

    double sumSq = 0;
    for (int j = start; j < end; j++) {
      sumSq += samples[j] * samples[j];
    }
    final rms = math.sqrt(sumSq / (end - start));
    if (rms > peak) peak = rms;
    amps[i] = rms;
  }

  if (peak > 0) {
    for (int i = 0; i < count; i++) {
      amps[i] /= peak;
    }
  }
  return amps;
}

/// Fallback for unknown formats: byte standard deviation per chunk.
List<double> _stdDevChunks(Uint8List bytes, int from, int to, int count) {
  final dataLen = to - from;
  if (dataLen <= 0) return List.filled(count, 0.0);

  final chunkSize = math.max(1, dataLen ~/ count);
  final amps = List<double>.filled(count, 0.0);
  double peak = 0;

  for (int i = 0; i < count; i++) {
    final start = from + i * chunkSize;
    final end = math.min(start + chunkSize, to);
    if (start >= to) break;

    final n = end - start;
    double sum = 0;
    for (int j = start; j < end; j++) {
      sum += bytes[j];
    }
    final mean = sum / n;

    double varSum = 0;
    for (int j = start; j < end; j++) {
      final d = bytes[j] - mean;
      varSum += d * d;
    }
    final sd = math.sqrt(varSum / n);
    if (sd > peak) peak = sd;
    amps[i] = sd;
  }

  if (peak > 0) {
    for (int i = 0; i < count; i++) {
      amps[i] /= peak;
    }
  }
  return amps;
}
