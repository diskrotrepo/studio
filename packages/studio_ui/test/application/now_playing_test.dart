import 'package:flutter_test/flutter_test.dart';
import 'package:studio_ui/application/now_playing.dart';

PlayingTrack _track(String id) =>
    PlayingTrack(id: id, title: 'Track $id', audioUrl: 'http://x/$id.mp3');

void main() {
  late NowPlaying np;

  setUp(() {
    // Reset the singleton state before each test.
    NowPlaying.instance.stop(clearQueue: true);
    NowPlaying.instance.playing.value = false;
    np = NowPlaying.instance;
  });

  group('play', () {
    test('sets track and queue with single item', () {
      np.play(_track('a'));

      expect(np.track.value, isNotNull);
      expect(np.track.value!.id, 'a');
      expect(np.queue.value, hasLength(1));
      expect(np.index.value, 0);
    });

    test('replaces previous queue', () {
      np.play(_track('a'));
      np.play(_track('b'));

      expect(np.queue.value, hasLength(1));
      expect(np.track.value!.id, 'b');
    });
  });

  group('stop', () {
    test('clears track and index', () {
      np.play(_track('a'));
      np.stop();

      expect(np.track.value, isNull);
      expect(np.index.value, -1);
      expect(np.hasTrack, false);
    });

    test('preserves queue by default', () {
      np.play(_track('a'));
      np.stop();

      expect(np.queue.value, hasLength(1));
    });

    test('clears queue when requested', () {
      np.play(_track('a'));
      np.stop(clearQueue: true);

      expect(np.queue.value, isEmpty);
    });
  });

  group('setQueue', () {
    test('replaces queue and starts at given index', () {
      np.setQueue([_track('a'), _track('b'), _track('c')], startAt: 1);

      expect(np.queue.value, hasLength(3));
      expect(np.index.value, 1);
      expect(np.track.value!.id, 'b');
    });

    test('clamps startAt to valid range', () {
      np.setQueue([_track('a'), _track('b')], startAt: 99);

      expect(np.index.value, 1); // clamped to last
    });

    test('handles empty list', () {
      np.setQueue([]);

      expect(np.queue.value, isEmpty);
      expect(np.index.value, -1);
      expect(np.track.value, isNull);
    });

    test('autoplay false sets track to null', () {
      np.setQueue([_track('a')], autoplay: false);

      expect(np.queue.value, hasLength(1));
      expect(np.index.value, 0);
      expect(np.track.value, isNull);
    });
  });

  group('prepareQueue', () {
    test('sets queue but does not set track', () {
      np.prepareQueue([_track('a'), _track('b')]);

      expect(np.queue.value, hasLength(2));
      expect(np.track.value, isNull);
    });
  });

  group('next / previous', () {
    test('next advances to next track', () {
      np.setQueue([_track('a'), _track('b'), _track('c')], startAt: 0);
      np.next();

      expect(np.index.value, 1);
      expect(np.track.value!.id, 'b');
    });

    test('next does nothing at end of queue', () {
      np.setQueue([_track('a'), _track('b')], startAt: 1);
      np.next();

      expect(np.index.value, 1);
      expect(np.track.value!.id, 'b');
    });

    test('previous goes to previous track', () {
      np.setQueue([_track('a'), _track('b'), _track('c')], startAt: 2);
      np.previous();

      expect(np.index.value, 1);
      expect(np.track.value!.id, 'b');
    });

    test('previous does nothing at start of queue', () {
      np.setQueue([_track('a'), _track('b')], startAt: 0);
      np.previous();

      expect(np.index.value, 0);
      expect(np.track.value!.id, 'a');
    });

    test('hasNext and hasPrevious reflect position', () {
      np.setQueue([_track('a'), _track('b'), _track('c')], startAt: 1);

      expect(np.hasNext, true);
      expect(np.hasPrevious, true);

      np.next(); // index 2
      expect(np.hasNext, false);
      expect(np.hasPrevious, true);

      np.previous(); // index 1
      np.previous(); // index 0
      expect(np.hasNext, true);
      expect(np.hasPrevious, false);
    });
  });

  group('enqueue', () {
    test('adds to end of queue', () {
      np.setQueue([_track('a')]);
      np.enqueue(_track('b'));

      expect(np.queue.value, hasLength(2));
      expect(np.queue.value.last.id, 'b');
    });
  });

  group('enqueueAll', () {
    test('adds multiple to end', () {
      np.setQueue([_track('a')]);
      np.enqueueAll([_track('b'), _track('c')]);

      expect(np.queue.value, hasLength(3));
    });

    test('does nothing for empty list', () {
      np.setQueue([_track('a')]);
      np.enqueueAll([]);

      expect(np.queue.value, hasLength(1));
    });
  });

  group('enqueueNext', () {
    test('inserts after current track', () {
      np.setQueue([_track('a'), _track('c')], startAt: 0);
      np.enqueueNext(_track('b'));

      expect(np.queue.value[1].id, 'b');
      expect(np.queue.value[2].id, 'c');
    });

    test('inserts at start when no current track', () {
      np.stop(clearQueue: true);
      np.enqueueNext(_track('x'));

      expect(np.queue.value.first.id, 'x');
    });
  });

  group('playNow', () {
    test('replaces current track in queue', () {
      np.setQueue([_track('a'), _track('b')], startAt: 0);
      np.playNow(_track('z'));

      expect(np.track.value!.id, 'z');
      expect(np.queue.value[0].id, 'z');
      expect(np.queue.value[1].id, 'b');
    });

    test('creates new queue when nothing is playing', () {
      np.stop(clearQueue: true);
      np.playNow(_track('x'));

      expect(np.queue.value, hasLength(1));
      expect(np.track.value!.id, 'x');
    });
  });

  group('playIndex', () {
    test('jumps to specified index', () {
      np.setQueue([_track('a'), _track('b'), _track('c')]);
      np.playIndex(2);

      expect(np.index.value, 2);
      expect(np.track.value!.id, 'c');
    });

    test('ignores out of bounds index', () {
      np.setQueue([_track('a')]);
      np.playIndex(5);

      expect(np.index.value, 0);
      expect(np.track.value!.id, 'a');
    });

    test('ignores negative index', () {
      np.setQueue([_track('a')]);
      np.playIndex(-1);

      expect(np.index.value, 0);
    });
  });

  group('playById', () {
    test('finds and plays track by id', () {
      np.setQueue([_track('a'), _track('b'), _track('c')]);
      np.playById('c');

      expect(np.index.value, 2);
      expect(np.track.value!.id, 'c');
    });

    test('does nothing for unknown id', () {
      np.setQueue([_track('a')]);
      np.playById('nonexistent');

      expect(np.index.value, 0);
    });
  });

  group('removeAt', () {
    test('removes item and shifts index when before current', () {
      np.setQueue([_track('a'), _track('b'), _track('c')], startAt: 2);
      np.removeAt(0);

      expect(np.queue.value, hasLength(2));
      expect(np.index.value, 1); // shifted back
      expect(np.track.value!.id, 'c');
    });

    test('removes current track and plays next', () {
      np.setQueue([_track('a'), _track('b'), _track('c')], startAt: 1);
      np.removeAt(1);

      expect(np.queue.value, hasLength(2));
      expect(np.track.value!.id, 'c');
    });

    test('removes last item and stops', () {
      np.setQueue([_track('a')]);
      np.removeAt(0);

      expect(np.queue.value, isEmpty);
      expect(np.track.value, isNull);
    });

    test('ignores out of bounds', () {
      np.setQueue([_track('a')]);
      np.removeAt(5);

      expect(np.queue.value, hasLength(1));
    });

    test('ignores negative index', () {
      np.setQueue([_track('a')]);
      np.removeAt(-1);

      expect(np.queue.value, hasLength(1));
    });

    test('removing item after current does not change index', () {
      np.setQueue([_track('a'), _track('b'), _track('c')], startAt: 0);
      np.removeAt(2);

      expect(np.index.value, 0);
      expect(np.track.value!.id, 'a');
      expect(np.queue.value, hasLength(2));
    });
  });

  group('clearQueue', () {
    test('empties queue and stops', () {
      np.setQueue([_track('a'), _track('b')]);
      np.clearQueue();

      expect(np.queue.value, isEmpty);
      expect(np.track.value, isNull);
      expect(np.index.value, -1);
    });
  });

  group('queueView', () {
    test('returns unmodifiable list', () {
      np.setQueue([_track('a'), _track('b')]);
      final view = np.queueView;

      expect(view, hasLength(2));
      expect(() => view.add(_track('c')), throwsUnsupportedError);
    });
  });
}
