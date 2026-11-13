import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../data/book_names.dart';

enum ChapterAudioStatus { idle, loading, playing, paused, error }

class RecordedAudioCatalog {
  final Map<String, Uri> chapters;
  final String narrator, source, license, editionNote;
  final String translation;
  final Map<String, RecordedAudioCatalog> alternatives;
  const RecordedAudioCatalog(
      this.chapters, this.narrator, this.source, this.license, this.editionNote,
      {this.translation = 'web', this.alternatives = const {}});
  static Future<RecordedAudioCatalog> load() async {
    final editions = <String, RecordedAudioCatalog>{};
    for (final id in ['web', 'bsb']) {
      editions[id] = RecordedAudioCatalog.fromJson(
          jsonDecode(await rootBundle.loadString('assets/audio/$id.json'))
              as Map<String, dynamic>);
    }
    final web = editions['web']!;
    return RecordedAudioCatalog(
        web.chapters, web.narrator, web.source, web.license, web.editionNote,
        alternatives: {'bsb': editions['bsb']!});
  }

  factory RecordedAudioCatalog.fromJson(Map<String, dynamic> json) {
    final translation = json['translation'] as String;
    if (translation != 'web' && translation != 'bsb') {
      throw const FormatException('Unexpected audio edition.');
    }
    final chapters = <String, Uri>{};
    for (final entry in (json['chapters'] as Map<String, dynamic>).entries) {
      final uri = Uri.parse(entry.value as String);
      if (!RegExp(r'^\w+\.\d+$').hasMatch(entry.key) ||
          uri.scheme != 'https' ||
          uri.host !=
              (translation == 'web'
                  ? 'www.publicdomainaudiobibles.com'
                  : 'openbible.com') ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          (translation == 'bsb' && !uri.path.startsWith('/audio/souer/')) ||
          !uri.path.endsWith('.mp3')) {
        throw const FormatException('Invalid audio chapter mapping.');
      }
      chapters[entry.key] = uri;
    }
    return RecordedAudioCatalog(
        chapters,
        json['narrator'] as String,
        json['source'] as String,
        json['license'] as String,
        json['editionNote'] as String,
        translation: translation);
  }
  Uri? chapter(String translation, String book, int chapter) =>
      translation == this.translation
          ? chapters['$book.$chapter']
          : alternatives[translation]?.chapter(translation, book, chapter);
}

class AudioSignal {
  final bool playing, loading, completed, failed;
  final Duration? position, duration;
  final bool progressOnly;
  const AudioSignal(
      {this.playing = false,
      this.loading = false,
      this.completed = false,
      this.failed = false,
      this.position,
      this.duration,
      this.progressOnly = false});
}

abstract class ChapterAudioBackend {
  Stream<AudioSignal> get signals;
  Future<void> load(Uri url);
  Future<void> play();
  Future<void> pause();
  Future<void> rewind();
  Future<void> stop();
  Future<void> dispose();
}

/// Speak bounded chunks so Android input limits cannot truncate long chapters.
/// Pausing stops the current chunk; resuming repeats that short chunk.
class DeviceSpeechBackend implements ChapterAudioBackend {
  final FlutterTts tts;
  final events = StreamController<AudioSignal>.broadcast();
  DeviceSpeechBackend({FlutterTts? engine}) : tts = engine ?? FlutterTts();
  List<String> chunks = [];
  int cursor = 0, generation = 0;
  bool disposed = false;
  @override
  Stream<AudioSignal> get signals => events.stream;
  void emit(AudioSignal signal) {
    if (!disposed) events.add(signal);
  }

  static List<String> splitText(String text) {
    final chunks = <String>[];
    var chunk = '';
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      if (chunk.length + word.length > 500 && chunk.isNotEmpty) {
        chunks.add(chunk);
        chunk = '';
      }
      chunk = chunk.isEmpty ? word : '$chunk $word';
    }
    if (chunk.isNotEmpty) chunks.add(chunk);
    return chunks;
  }

  @override
  Future<void> load(Uri url) async {
    chunks = splitText(url.data!.contentAsString());
    cursor = 0;
    if (chunks.isEmpty) throw StateError('No chapter text');
    await tts.awaitSpeakCompletion(true);
    final language = url.data!.parameters['language'] ?? 'en-US';
    var ready = await tts.setLanguage(language) == 1;
    if (!ready && language == 'fil-PH') {
      ready = await tts.setLanguage('tl-PH') == 1;
    }
    if (!ready) {
      throw StateError('Requested speech voice unavailable');
    }
    await tts.setSpeechRate(.45);
  }

  @override
  Future<void> play() async {
    final run = ++generation;
    while (!disposed && run == generation && cursor < chunks.length) {
      emit(AudioSignal(
          playing: true,
          position: Duration(
              milliseconds:
                  chunks.take(cursor).fold<int>(0, (n, s) => n + s.length)),
          duration: Duration(
              milliseconds: chunks.fold<int>(0, (n, s) => n + s.length))));
      final result = await tts.speak(chunks[cursor]);
      if (disposed || run != generation) return;
      if (result != 1) throw StateError('Speech playback failed');
      cursor++;
    }
    if (!disposed && run == generation) {
      emit(const AudioSignal(completed: true));
    }
  }

  @override
  Future<void> pause() async {
    generation++;
    await tts.stop();
  }

  @override
  Future<void> rewind() async {
    await stop();
  }

  @override
  Future<void> stop() async {
    generation++;
    cursor = 0;
    await tts.stop();
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await stop();
    await events.close();
  }
}

class StreamingAudioBackend implements ChapterAudioBackend {
  String mediaTitle = 'Bible audio';
  String mediaAlbum = 'SELAH';
  final player = AudioPlayer();
  final events = StreamController<AudioSignal>.broadcast();
  late final StreamSubscription<PlayerState> states;
  late final StreamSubscription<PlayerException> errors;
  late final StreamSubscription<Duration> positions;
  late final StreamSubscription<Duration?> durations;
  StreamingAudioBackend() {
    states = player.playerStateStream.listen((state) => events.add(AudioSignal(
          playing: state.playing,
          loading: state.processingState == ProcessingState.loading ||
              state.processingState == ProcessingState.buffering,
          completed: state.processingState == ProcessingState.completed,
          position: player.position,
          duration: player.duration,
        )));
    void progress() => events.add(AudioSignal(
        progressOnly: true,
        position: player.position,
        duration: player.duration));
    positions = player
        .createPositionStream(
            minPeriod: const Duration(milliseconds: 500),
            maxPeriod: const Duration(milliseconds: 500))
        .listen((_) => progress());
    durations = player.durationStream.listen((_) => progress());
    errors = player.errorStream
        .listen((_) => events.add(const AudioSignal(failed: true)));
  }
  @override
  Stream<AudioSignal> get signals => events.stream;
  @override
  Future<void> load(Uri url) async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    await player.setAudioSource(AudioSource.uri(url,
        tag: MediaItem(
            id: url.toString(),
            title: mediaTitle,
            album: mediaAlbum,
            artist: 'SELAH • Recorded Bible narration')));
  }

  @override
  Future<void> play() => player.play();
  @override
  Future<void> pause() => player.pause();
  @override
  Future<void> rewind() => player.seek(Duration.zero);
  @override
  Future<void> stop() => player.stop();
  @override
  Future<void> dispose() async {
    await states.cancel();
    await errors.cancel();
    await positions.cancel();
    await durations.cancel();
    await player.dispose();
    await events.close();
  }
}

/// Manual chapter/edition changes invalidate pending loads. Natural completion
/// can request continuation from the reader's canonical chapter order.
class ChapterAudioController extends ChangeNotifier {
  void Function(String scope)? onCompleted;
  final ChapterAudioBackend Function() backendFactory;
  final ChapterAudioBackend Function() speechBackendFactory;
  final Future<RecordedAudioCatalog> Function() catalogLoader;
  ChapterAudioController(
      {ChapterAudioBackend Function()? backendFactory,
      ChapterAudioBackend Function()? speechBackendFactory,
      Future<RecordedAudioCatalog> Function()? catalogLoader})
      : backendFactory = backendFactory ?? StreamingAudioBackend.new,
        speechBackendFactory = speechBackendFactory ?? DeviceSpeechBackend.new,
        catalogLoader = catalogLoader ?? RecordedAudioCatalog.load;
  ChapterAudioBackend? _backend;
  bool _speechBackend = false;
  StreamSubscription<AudioSignal>? _subscription;
  Future<RecordedAudioCatalog>? _catalog;
  ChapterAudioStatus status = ChapterAudioStatus.idle;
  String? error;
  String? _scope;
  String? get scope => _scope;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  double? get progress => duration.inMicroseconds > 0
      ? (position.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0)
      : null;
  Uri? _loaded;
  bool _completed = false;
  bool _acceptSignals = false;
  bool _disposed = false;
  int _generation = 0;
  Future<void> _stopping = Future.value();

  static bool available(String translation) =>
      translation == 'web' || translation == 'bsb' || usesSpeech(translation);
  static bool usesFilipinoVoice(String translation) =>
      translation == 'mbbceb99' || translation == 'cebocb';
  static bool usesSpeech(String translation) =>
      translation == 'nlt' || usesFilipinoVoice(translation);
  bool get _speechScope => usesSpeech(_scope?.split(':').first ?? '');
  bool get playing => status == ChapterAudioStatus.playing;
  bool get loading => status == ChapterAudioStatus.loading;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _failed() {
    _generation++;
    status = ChapterAudioStatus.error;
    error = _speechScope
        ? 'Text-to-speech could not play. Install or enable ${usesFilipinoVoice(_scope!.split(':').first) ? 'a Filipino/Tagalog' : 'an English'} speech voice in your device or browser, then retry.'
        : 'Audio could not play. Check your internet connection and tap Play to retry.';
    _acceptSignals = false;
    _loaded = null;
    _catalog = null;
    position = Duration.zero;
    duration = Duration.zero;
    if (_backend != null) {
      _stopping = _backend!.stop().catchError((Object _) {});
    }
    _emit();
  }

  ChapterAudioBackend get backend {
    if (_backend == null) {
      _speechBackend = _speechScope;
      _backend = _speechBackend ? speechBackendFactory() : backendFactory();
      _subscription = _backend!.signals.listen((signal) {
        if (_disposed || !_acceptSignals) return;
        if (signal.failed) {
          _failed();
          return;
        }
        if (signal.position != null) position = signal.position!;
        if (signal.duration != null) duration = signal.duration!;
        if (signal.progressOnly) {
          _emit();
          return;
        }
        if (signal.completed) {
          if (_completed) return;
          _completed = true;
          status = ChapterAudioStatus.idle;
        } else if (signal.loading) {
          status = ChapterAudioStatus.loading;
        } else {
          status = signal.playing
              ? ChapterAudioStatus.playing
              : ChapterAudioStatus.paused;
        }
        _emit();
        if (signal.completed && _completed && _scope != null) {
          onCompleted?.call(_scope!);
        }
      });
    }
    return _backend!;
  }

  Future<void> toggle(String translation, String book, int chapter,
      {bool continuePlayback = false, String? chapterText}) async {
    if (_disposed) return;
    final scope = '$translation:$book.$chapter';
    if (!available(translation)) {
      await stop();
      return;
    }
    if (loading && _scope == scope) return;
    if (_scope != scope) {
      if (continuePlayback && _completed && _scope != null) {
        // Keep the foreground media service alive at a natural chapter boundary.
        _generation++;
        _acceptSignals = false;
        _loaded = null;
        _completed = false;
        position = Duration.zero;
        duration = Duration.zero;
      } else {
        final stopping = stop();
        final stoppedGeneration = _generation;
        await stopping;
        if (_disposed || stoppedGeneration != _generation) return;
      }
      _scope = scope;
    }
    if (_backend != null && _speechBackend != usesSpeech(translation)) {
      final generation = _generation;
      await _subscription?.cancel();
      final old = _backend!;
      _backend = null;
      await old.dispose();
      if (_disposed || generation != _generation) return;
    }
    if (_disposed) return;
    if (playing) {
      final generation = _generation;
      status = ChapterAudioStatus.paused;
      _emit();
      try {
        await backend.pause();
      } catch (_) {
        if (!_disposed && generation == _generation) _failed();
      }
      return;
    }
    final generation = ++_generation;
    status = ChapterAudioStatus.loading;
    error = null;
    _acceptSignals = false;
    _emit();
    try {
      await _stopping;
      final catalog =
          usesSpeech(translation) ? null : await (_catalog ??= catalogLoader());
      if (_disposed || generation != _generation) return;
      final url = usesSpeech(translation)
          ? (chapterText == null || chapterText.trim().isEmpty
              ? null
              : Uri.dataFromString(chapterText,
                  mimeType: 'text/plain',
                  encoding: utf8,
                  parameters: {
                      'language':
                          usesFilipinoVoice(translation) ? 'fil-PH' : 'en-US'
                    }))
          : catalog!.chapter(translation, book, chapter);
      if (url == null) {
        throw StateError('No verified recording for this chapter.');
      }
      if (_loaded != url) {
        final output = backend;
        if (output is StreamingAudioBackend) {
          const ids = [
            'GEN',
            'EXO',
            'LEV',
            'NUM',
            'DEU',
            'JOS',
            'JDG',
            'RUT',
            '1SA',
            '2SA',
            '1KI',
            '2KI',
            '1CH',
            '2CH',
            'EZR',
            'NEH',
            'EST',
            'JOB',
            'PSA',
            'PRO',
            'ECC',
            'SNG',
            'ISA',
            'JER',
            'LAM',
            'EZK',
            'DAN',
            'HOS',
            'JOL',
            'AMO',
            'OBA',
            'JON',
            'MIC',
            'NAM',
            'HAB',
            'ZEP',
            'HAG',
            'ZEC',
            'MAL',
            'MAT',
            'MRK',
            'LUK',
            'JHN',
            'ACT',
            'ROM',
            '1CO',
            '2CO',
            'GAL',
            'EPH',
            'PHP',
            'COL',
            '1TH',
            '2TH',
            '1TI',
            '2TI',
            'TIT',
            'PHM',
            'HEB',
            'JAS',
            '1PE',
            '2PE',
            '1JN',
            '2JN',
            '3JN',
            'JUD',
            'REV'
          ];
          final index = ids.indexOf(book);
          output.mediaTitle =
              '${index < 0 ? book : englishBookNames[index]} $chapter';
          output.mediaAlbum = '${translation.toUpperCase()} • Bible';
        }
        await backend.load(url).timeout(const Duration(seconds: 25));
        if (_disposed || generation != _generation) return;
        _loaded = url;
        _completed = false;
      } else if (_completed) {
        position = Duration.zero;
        await backend.rewind();
        _completed = false;
      }
      if (_disposed || generation != _generation) return;
      _acceptSignals = true;
      status = ChapterAudioStatus.playing;
      _emit();
      unawaited(backend.play().catchError((Object _) {
        if (!_disposed && generation == _generation) _failed();
      }));
    } catch (_) {
      if (!_disposed && generation == _generation) _failed();
    }
  }

  Future<void> stop() {
    _generation++;
    _acceptSignals = false;
    _scope = null;
    _loaded = null;
    _completed = false;
    position = Duration.zero;
    duration = Duration.zero;
    status = ChapterAudioStatus.idle;
    error = null;
    _emit();
    if (_backend != null) {
      _stopping = _backend!.stop().catchError((Object _) {});
    }
    return _stopping;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_subscription?.cancel() ?? Future.value());
    if (_backend != null) {
      unawaited(_backend!.dispose().catchError((Object _) {}));
    }
    super.dispose();
  }
}
