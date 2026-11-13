import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/data/bible.dart';
import 'package:selah/features/audio/chapter_audio.dart';

class FakeAudioBackend implements ChapterAudioBackend {
  final events = StreamController<AudioSignal>.broadcast(sync: true);
  final loads = <Uri>[];
  int plays = 0, pauses = 0, rewinds = 0, stops = 0;
  bool fail = false;
  Completer<void>? pending;
  @override
  Stream<AudioSignal> get signals => events.stream;
  @override
  Future<void> load(Uri uri) async {
    loads.add(uri);
    if (fail) throw StateError('Offline');
    await pending?.future;
  }

  @override
  Future<void> play() async {
    plays++;
    events.add(const AudioSignal(playing: true));
  }

  @override
  Future<void> pause() async {
    pauses++;
    events.add(const AudioSignal());
  }

  @override
  Future<void> rewind() async {
    rewinds++;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    await events.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RecordedAudioCatalog catalog;
  setUpAll(() async => catalog = await RecordedAudioCatalog.load());

  for (final edition in ['mbbceb99', 'cebocb']) {
    test('$edition uses Filipino speech with the original Cebuano text',
        () async {
      final speech = FakeAudioBackend();
      final audio = ChapterAudioController(
          speechBackendFactory: () => speech,
          catalogLoader: () async =>
              throw StateError('No recording request expected'));
      addTearDown(audio.dispose);
      const text = 'Sa sinugdan gibuhat sa Dios ang langit ug ang yuta.';
      await audio.toggle(edition, 'GEN', 1, chapterText: text);
      expect(speech.loads.single.data!.contentAsString(), text);
      expect(speech.loads.single.data!.parameters['language'], 'fil-PH');
      expect(audio.playing, isTrue);
      await audio.toggle(edition, 'GEN', 1, chapterText: text);
      expect(audio.status, ChapterAudioStatus.paused);
    });
  }

  test(
      'NLT speaks selected text without a recording request and stops on edition change',
      () async {
    final speech = FakeAudioBackend();
    final recording = FakeAudioBackend();
    var catalogRequests = 0;
    final audio = ChapterAudioController(
        backendFactory: () => recording,
        speechBackendFactory: () => speech,
        catalogLoader: () async {
          catalogRequests++;
          return catalog;
        });
    addTearDown(audio.dispose);
    await audio.toggle('nlt', 'JHN', 3,
        chapterText: 'Selected NLT chapter text.');
    expect(speech.loads.single.data!.contentAsString(),
        'Selected NLT chapter text.');
    expect(catalogRequests, 0);
    expect(audio.playing, isTrue);
    await audio.toggle('nlt', 'JHN', 3,
        chapterText: 'Selected NLT chapter text.');
    expect(speech.pauses, 1);
    await audio.toggle('nlt', 'JHN', 3,
        chapterText: 'Selected NLT chapter text.');
    expect(speech.plays, 2);
    var completions = 0;
    audio.onCompleted = (_) => completions++;
    speech.events.add(const AudioSignal(completed: true));
    speech.events.add(const AudioSignal(completed: true));
    expect(completions, 1);
    await audio.toggle('web', 'GEN', 1);
    expect(recording.loads.single, catalog.chapter('web', 'GEN', 1));
    expect(speech.stops, greaterThan(0));
    expect(catalogRequests, 1);
  });

  test('Speech chunks retain words and keep long chapters within input limits',
      () {
    final text = List.generate(4000, (n) => 'word$n').join(' ');
    final chunks = DeviceSpeechBackend.splitText(text);
    expect(chunks.join(' '), text);
    expect(chunks.every((chunk) => chunk.length <= 500), isTrue);
    expect(chunks.length, greaterThan(1));
  });

  test('NLT missing chapter text gives a speech-specific error', () async {
    final speech = FakeAudioBackend();
    final audio = ChapterAudioController(speechBackendFactory: () => speech);
    addTearDown(audio.dispose);
    await audio.toggle('nlt', 'GEN', 1);
    expect(audio.status, ChapterAudioStatus.error);
    expect(audio.error, contains('speech'));
    expect(speech.loads, isEmpty);
  });

  test(
      'Verified WEB catalog covers every chapter and never substitutes editions',
      () async {
    final bible = await Bible.load();
    expect(catalog.chapters.length, 1189);
    for (final book in bible.books) {
      for (int chapter = 1; chapter <= book.chapters.length; chapter++) {
        expect(catalog.chapter('web', book.id, chapter), isNotNull);
      }
    }
    expect(catalog.chapter('cebocb', 'GEN', 1), isNull);
    expect(catalog.chapter('asv', 'GEN', 1), isNull);
    expect(catalog.chapter('tglulb', 'GEN', 1), isNull);
    expect(catalog.alternatives['bsb']!.narrator, 'Bob Souer');
    expect(catalog.alternatives['bsb']!.chapters.length, 1189);
    for (final book in bible.books) {
      for (int chapter = 1; chapter <= book.chapters.length; chapter++) {
        expect(catalog.chapter('bsb', book.id, chapter), isNotNull);
      }
    }
    expect(catalog.narrator, 'David Williams');
    expect(catalog.editionNote, contains('earlier WEB edition'));
  });

  test(
      'Play, pause and resume retain the selected chapter; completion can replay',
      () async {
    final backend = FakeAudioBackend();
    final audio = ChapterAudioController(
        backendFactory: () => backend, catalogLoader: () async => catalog);
    addTearDown(audio.dispose);
    await audio.toggle('web', '1CH', 2);
    expect(audio.playing, isTrue);
    expect(backend.loads.single, catalog.chapter('web', '1CH', 2));
    await audio.toggle('web', '1CH', 2);
    expect(audio.status, ChapterAudioStatus.paused);
    await audio.toggle('web', '1CH', 2);
    expect(backend.loads.length, 1);
    expect(backend.plays, 2);
    backend.events.add(const AudioSignal(completed: true));
    expect(audio.status, ChapterAudioStatus.idle);
    await audio.toggle('web', '1CH', 2);
    expect(backend.rewinds, 1);
    expect(audio.playing, isTrue);
    await audio.toggle('asv', '1CH', 2);
    expect(audio.status, ChapterAudioStatus.idle);
  });

  test('Switching from WEB to BSB loads the matching recording', () async {
    final backend = FakeAudioBackend();
    final audio = ChapterAudioController(
        backendFactory: () => backend, catalogLoader: () async => catalog);
    addTearDown(audio.dispose);
    await audio.toggle('web', 'GEN', 1);
    await audio.toggle('bsb', 'GEN', 1);
    expect(backend.loads.last, catalog.chapter('bsb', 'GEN', 1));
    expect(backend.loads.last, isNot(backend.loads.first));
    expect(backend.stops, greaterThan(0));
    expect(audio.playing, isTrue);
    await audio.toggle('tglulb', 'GEN', 1);
    expect(audio.status, ChapterAudioStatus.idle);
    expect(backend.loads.length, 2);
  });

  test(
      'Natural continuation keeps the background player alive between chapters',
      () async {
    final backend = FakeAudioBackend();
    final audio = ChapterAudioController(
        backendFactory: () => backend, catalogLoader: () async => catalog);
    addTearDown(audio.dispose);
    await audio.toggle('web', 'GEN', 1);
    final stops = backend.stops;
    backend.events.add(const AudioSignal(completed: true));
    await audio.toggle('web', 'GEN', 2, continuePlayback: true);
    expect(backend.stops, stops);
    expect(audio.scope, 'web:GEN.2');
    expect(audio.playing, isTrue);
    expect(backend.loads.last, catalog.chapter('web', 'GEN', 2));
    // Manual navigation still stops the previous recording.
    await audio.toggle('web', 'GEN', 3);
    expect(backend.stops, greaterThan(stops));
  });

  test(
      'Natural completion requests continuation once; stop ignores stale events',
      () async {
    final backend = FakeAudioBackend();
    final audio = ChapterAudioController(
        backendFactory: () => backend, catalogLoader: () async => catalog);
    addTearDown(audio.dispose);
    final finished = <String>[];
    audio.onCompleted = finished.add;
    await audio.toggle('web', 'GEN', 1);
    backend.events.add(const AudioSignal(completed: true));
    backend.events.add(const AudioSignal(completed: true));
    expect(finished, ['web:GEN.1']);
    await audio.toggle('web', 'GEN', 2);
    await audio.stop();
    backend.events.add(const AudioSignal(completed: true));
    expect(finished, ['web:GEN.1']);
  });

  test('Stopping during a pending load cannot start stale chapter audio',
      () async {
    final backend = FakeAudioBackend()..pending = Completer<void>();
    final audio = ChapterAudioController(
        backendFactory: () => backend, catalogLoader: () async => catalog);
    addTearDown(audio.dispose);
    final playback = audio.toggle('web', 'GEN', 1);
    await Future<void>.delayed(Duration.zero);
    expect(audio.loading, isTrue);
    await audio.stop();
    backend.pending!.complete();
    await playback;
    expect(backend.plays, 0);
    expect(audio.status, ChapterAudioStatus.idle);
  });

  test('A failed stream offers retry and does not choose another recording',
      () async {
    final backend = FakeAudioBackend()..fail = true;
    final audio = ChapterAudioController(
        backendFactory: () => backend, catalogLoader: () async => catalog);
    addTearDown(audio.dispose);
    await audio.toggle('web', 'JHN', 3);
    expect(audio.status, ChapterAudioStatus.error);
    expect(audio.error, contains('internet'));
    backend.fail = false;
    await audio.toggle('web', 'JHN', 3);
    expect(audio.playing, isTrue);
    expect(
        backend.loads.every((uri) => uri == catalog.chapter('web', 'JHN', 3)),
        isTrue);
  });
}
