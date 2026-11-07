import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

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
  const AudioSignal(
      {this.playing = false,
      this.loading = false,
      this.completed = false,
      this.failed = false});
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

class StreamingAudioBackend implements ChapterAudioBackend {
  final player = AudioPlayer();
  final events = StreamController<AudioSignal>.broadcast();
  late final StreamSubscription<PlayerState> states;
  late final StreamSubscription<PlayerException> errors;
  StreamingAudioBackend() {
    states = player.playerStateStream.listen((state) => events.add(AudioSignal(
          playing: state.playing,
          loading: state.processingState == ProcessingState.loading ||
              state.processingState == ProcessingState.buffering,
          completed: state.processingState == ProcessingState.completed,
        )));
    errors = player.errorStream
        .listen((_) => events.add(const AudioSignal(failed: true)));
  }
  @override
  Stream<AudioSignal> get signals => events.stream;
  @override
  Future<void> load(Uri url) async {
    await player.setUrl(url.toString());
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
    await player.dispose();
    await events.close();
  }
}

/// A chapter/edition change invalidates pending loads and never autoplays a new one.
class ChapterAudioController extends ChangeNotifier {
  final ChapterAudioBackend Function() backendFactory;
  final Future<RecordedAudioCatalog> Function() catalogLoader;
  ChapterAudioController(
      {ChapterAudioBackend Function()? backendFactory,
      Future<RecordedAudioCatalog> Function()? catalogLoader})
      : backendFactory = backendFactory ?? StreamingAudioBackend.new,
        catalogLoader = catalogLoader ?? RecordedAudioCatalog.load;
  ChapterAudioBackend? _backend;
  StreamSubscription<AudioSignal>? _subscription;
  Future<RecordedAudioCatalog>? _catalog;
  ChapterAudioStatus status = ChapterAudioStatus.idle;
  String? error;
  String? _scope;
  Uri? _loaded;
  bool _completed = false;
  bool _acceptSignals = false;
  bool _disposed = false;
  int _generation = 0;
  Future<void> _stopping = Future.value();

  static bool available(String translation) =>
      translation == 'web' || translation == 'bsb';
  bool get playing => status == ChapterAudioStatus.playing;
  bool get loading => status == ChapterAudioStatus.loading;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _failed() {
    _generation++;
    status = ChapterAudioStatus.error;
    error =
        'Audio could not play. Check your internet connection and tap Play to retry.';
    _acceptSignals = false;
    _loaded = null;
    _catalog = null;
    if (_backend != null) {
      _stopping = _backend!.stop().catchError((Object _) {});
    }
    _emit();
  }

  ChapterAudioBackend get backend {
    if (_backend == null) {
      _backend = backendFactory();
      _subscription = _backend!.signals.listen((signal) {
        if (_disposed || !_acceptSignals) return;
        if (signal.failed) {
          _failed();
          return;
        }
        if (signal.completed) {
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
      });
    }
    return _backend!;
  }

  Future<void> toggle(String translation, String book, int chapter) async {
    if (_disposed) return;
    final scope = '$translation:$book.$chapter';
    if (!available(translation)) {
      await stop();
      return;
    }
    if (loading && _scope == scope) return;
    if (_scope != scope) {
      final stopping = stop();
      final stoppedGeneration = _generation;
      await stopping;
      if (_disposed || stoppedGeneration != _generation) return;
      _scope = scope;
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
      final catalog = await (_catalog ??= catalogLoader());
      if (_disposed || generation != _generation) return;
      final url = catalog.chapter(translation, book, chapter);
      if (url == null) {
        throw StateError('No verified recording for this chapter.');
      }
      if (_loaded != url) {
        await backend.load(url).timeout(const Duration(seconds: 25));
        if (_disposed || generation != _generation) return;
        _loaded = url;
        _completed = false;
      } else if (_completed) {
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
