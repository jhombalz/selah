import 'package:audio_service/audio_service.dart';

/// Chapter controls are owned by the reader, never a single-track repeat queue.
class BibleMediaHandler extends BaseAudioHandler {
  static BibleMediaHandler? instance;
  Future<void> Function()? onPlay, onPause, onStop;
  Future<void> Function(int direction)? onSkip;

  static Future<void> initialize() async {
    instance = await AudioService.init<BibleMediaHandler>(
        builder: BibleMediaHandler.new,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.example.selah.bible_audio',
          androidNotificationChannelName: 'Bible audio',
          androidNotificationIcon: 'drawable/ic_audio_notification',
          androidNotificationOngoing: false,
          androidStopForegroundOnPause: false,
        ));
  }

  void update(
      {required String? id,
      required String title,
      required String edition,
      required bool playing,
      required bool loading,
      required bool hasPrevious,
      required bool hasNext,
      Duration position = Duration.zero,
      Duration? duration}) {
    if (id != null) {
      final item = MediaItem(
          id: id,
          title: title,
          album: '$edition · SELAH',
          artist: 'Bible reading',
          duration: duration);
      final old = mediaItem.value;
      if (old?.id != item.id ||
          old?.duration != item.duration ||
          old?.album != item.album) {
        mediaItem.add(item);
      }
    }
    final controls = [
      if (hasPrevious) MediaControl.skipToPrevious,
      playing ? MediaControl.pause : MediaControl.play,
      if (hasNext) MediaControl.skipToNext,
    ];
    playbackState.add(PlaybackState(
      controls: id == null ? const [] : controls,
      androidCompactActionIndices:
          id == null ? const [] : List.generate(controls.length, (i) => i),
      processingState: id == null
          ? AudioProcessingState.idle
          : loading
              ? AudioProcessingState.loading
              : AudioProcessingState.ready,
      playing: playing,
      updatePosition: position,
    ));
  }

  @override
  Future<void> play() async => onPlay?.call();
  @override
  Future<void> pause() async => onPause?.call();
  @override
  Future<void> stop() async {
    await onStop?.call();
    playbackState.add(playbackState.value
        .copyWith(playing: false, processingState: AudioProcessingState.idle));
  }

  @override
  Future<void> skipToPrevious() async => onSkip?.call(-1);
  @override
  Future<void> skipToNext() async => onSkip?.call(1);
  @override
  Future<void> onNotificationDeleted() => stop();

  void unbind() {
    onPlay = onPause = onStop = null;
    onSkip = null;
    update(
        id: null,
        title: '',
        edition: '',
        playing: false,
        loading: false,
        hasPrevious: false,
        hasNext: false);
  }
}
