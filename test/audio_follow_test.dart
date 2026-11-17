import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/data/bible.dart';
import 'package:selah/data/user_backup.dart';
import 'package:selah/data/user_database.dart';
import 'package:selah/features/audio/chapter_audio.dart';
import 'package:selah/features/audio/bible_media_handler.dart';
import 'package:audio_service/audio_service.dart';
import 'package:selah/main.dart';
import 'chapter_audio_test.dart' show FakeAudioBackend;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Bible bible;
  late RecordedAudioCatalog catalog;
  setUpAll(() async {
    final bundled = await Bible.load();
    bible = Bible(bundled.books, 'Test WEB', id: 'web', abbreviation: 'WEB');
    catalog = await RecordedAudioCatalog.load();
  });

  testWidgets(
      'MBB completion and notification controls change the actual chapter',
      (tester) async {
    final db = UserDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final output = FakeAudioBackend();
    final audio = ChapterAudioController(
        backendFactory: () => output, catalogLoader: () async => catalog);
    final media = BibleMediaHandler();
    final small = Bible([
      BibleBook('GEN', 'Genesis', [
        [const BibleVerse('1', 'Daily verse fixture')]
      ]),
      BibleBook('MAT', 'Matthew', [
        [const BibleVerse('1', 'Chapter one')],
        [const BibleVerse('1', 'Chapter two')],
      ]),
      BibleBook('MRK', 'Mark', [
        [const BibleVerse('1', 'Next book')]
      ])
    ], 'MBB test', id: 'mbbceb99', abbreviation: 'MBBCEB99');
    await tester.pumpWidget(SelahApp(
        initialBible: small,
        database: db,
        audioController: audio,
        mediaHandler: media,
        initialData: const UserData(preferences: {'lastChapter': 'MAT.1'})));
    await media.play();
    await tester.pumpAndSettle();
    final first = output.loads.last;
    expect(media.mediaItem.value!.id, 'mbbceb99:MAT.1');
    expect(media.playbackState.value.controls, contains(MediaControl.pause));
    output.events.add(AudioSignal(completed: true, source: first));
    await tester.runAsync(db.load);
    await tester.pumpAndSettle();
    expect(output.loads.last, catalog.chapter('mbbceb99', 'MAT', 2));
    expect(media.mediaItem.value!.id, 'mbbceb99:MAT.2');
    expect(media.playbackState.value.controls, [
      MediaControl.skipToPrevious,
      MediaControl.pause,
      MediaControl.skipToNext
    ]);
    output.events.add(AudioSignal(completed: true, source: first));
    await tester.pumpAndSettle();
    expect(audio.scope, 'mbbceb99:MAT.2',
        reason: 'Old source completion must be ignored');
    await media.pause();
    await tester.pumpAndSettle();
    expect(audio.status, ChapterAudioStatus.paused);
    expect(media.playbackState.value.controls, contains(MediaControl.play));
    await media.play();
    await tester.pumpAndSettle();
    expect(audio.playing, isTrue);
    final duringSkip = <AudioProcessingState>[];
    final mediaStates = media.playbackState
        .listen((state) => duringSkip.add(state.processingState));
    await media.skipToPrevious();
    await tester.runAsync(db.load);
    await tester.pumpAndSettle();
    expect(audio.scope, 'mbbceb99:MAT.1');
    expect(duringSkip, isNot(contains(AudioProcessingState.idle)),
        reason: 'Chapter changes must not tear down the Android media session');
    unawaited(mediaStates.cancel());
    await media.skipToNext();
    await tester.runAsync(db.load);
    await tester.pumpAndSettle();
    expect(audio.scope, 'mbbceb99:MAT.2');
    await media.skipToNext();
    await tester.runAsync(db.load);
    await tester.pumpAndSettle();
    expect(audio.scope, 'mbbceb99:MRK.1');
    expect(media.playbackState.value.controls,
        isNot(contains(MediaControl.skipToNext)));
    await media.stop();
    await tester.pumpAndSettle();
    expect(audio.scope, isNull);
    expect(
        media.playbackState.value.processingState, AudioProcessingState.idle);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('TTS speed restores, changes during playback and persists',
      (tester) async {
    final db = UserDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final backend = FakeAudioBackend();
    final audio = ChapterAudioController(speechBackendFactory: () => backend);
    await tester.pumpWidget(SelahApp(
        initialBible:
            Bible(bible.books, 'Test NLT', id: 'nlt', abbreviation: 'NLT'),
        database: db,
        audioController: audio,
        initialData: const UserData(preferences: {'speechSpeed': '1.25'})));
    expect(audio.speechSpeed, 1.25);
    await tester.tap(find.text('Continue Reading'));
    await tester.runAsync(db.load);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chapter-audio')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AA'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('1.5×'));
    await tester.tap(find.text('1.5×'));
    await tester.runAsync(db.load);
    await tester.pumpAndSettle();
    expect(audio.speechSpeed, 1.5);
    expect(audio.playing, isTrue);
    expect(backend.pauses, 1);
    expect((await tester.runAsync(db.load))!.preferences['speechSpeed'], '1.5');
    final backup = UserBackup.create((await tester.runAsync(db.load))!, bible);
    expect(backup.data.preferences['speechSpeed'], '1.5');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('Playback progress cannot resume paused audio and is cleared on stop',
      () async {
    final backend = FakeAudioBackend();
    final audio = ChapterAudioController(
        backendFactory: () => backend, catalogLoader: () async => catalog);
    addTearDown(audio.dispose);
    await audio.toggle('web', 'GEN', 1);
    backend.events.add(const AudioSignal(
        progressOnly: true,
        position: Duration(seconds: 30),
        duration: Duration(seconds: 100)));
    expect(audio.progress, .3);
    await audio.toggle('web', 'GEN', 1);
    backend.events.add(const AudioSignal(
        progressOnly: true,
        position: Duration(seconds: 40),
        duration: Duration(seconds: 100)));
    expect(audio.status, ChapterAudioStatus.paused);
    await audio.stop();
    expect(audio.progress, isNull);
    backend.events.add(const AudioSignal(
        progressOnly: true,
        position: Duration(seconds: 70),
        duration: Duration(seconds: 100)));
    expect(audio.progress, isNull);
  });

  testWidgets(
      'Audio continues across chapters and books, and stops at the last chapter',
      (tester) async {
    final db = UserDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final backend = FakeAudioBackend();
    final audio = ChapterAudioController(
        backendFactory: () => backend, catalogLoader: () async => catalog);
    final smallBible = Bible([
      BibleBook('GEN', 'Genesis', [
        [const BibleVerse('1', 'First chapter')],
        [const BibleVerse('1', 'Second chapter')]
      ]),
      BibleBook('EXO', 'Exodus', [
        [const BibleVerse('1', 'Next book')]
      ])
    ], 'Test WEB', id: 'web', abbreviation: 'WEB');
    await tester.pumpWidget(SelahApp(
        initialBible: smallBible,
        database: db,
        audioController: audio,
        initialData: const UserData()));
    await tester.tap(find.text('Continue Reading'));
    await tester.runAsync(db.load);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chapter-audio')));
    await tester.pumpAndSettle();
    for (final expected in ['web:GEN.2', 'web:EXO.1']) {
      backend.events.add(const AudioSignal(completed: true));
      await tester.runAsync(db.load);
      await tester.pumpAndSettle();
      expect(audio.scope, expected);
      expect(audio.playing, isTrue);
    }
    expect(
        find.textContaining('Next book', findRichText: true), findsOneWidget);
    backend.events.add(const AudioSignal(completed: true));
    await tester.pumpAndSettle();
    expect(audio.status, ChapterAudioStatus.idle);
    expect(backend.plays, 3);
    await tester.runAsync(db.load);
    await tester.pumpWidget(const SizedBox());
  });

  for (final edition in ['web', 'nlt', 'mbb05']) {
    testWidgets(
        '$edition playback scrolls Scripture, manual scrolling suspends it, and resume follows again',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = UserDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final backend = FakeAudioBackend();
      final audio = ChapterAudioController(
          backendFactory: () => backend,
          speechBackendFactory: () => backend,
          catalogLoader: () async => catalog);
      await tester.pumpWidget(SelahApp(
          initialBible: Bible(bible.books, 'Test edition',
              id: edition, abbreviation: edition.toUpperCase()),
          database: db,
          audioController: audio,
          initialData: const UserData()));
      await tester.tap(find.text('Continue Reading'));
      await tester.runAsync(db.load);
      await tester.pumpAndSettle();
      final scroll = tester
          .widget<SingleChildScrollView>(
              find.byType(SingleChildScrollView).first)
          .controller!;
      await tester.tap(find.byKey(const ValueKey('chapter-audio')));
      await tester.pumpAndSettle();
      expect(audio.playing, isTrue);
      backend.events.add(const AudioSignal(
          progressOnly: true,
          position: Duration(seconds: 30),
          duration: Duration(seconds: 100)));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(100));
      await tester.drag(
          find.byType(SingleChildScrollView).first, const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(find.text('Resume auto-scroll'), findsOneWidget);
      final manual = scroll.offset;
      backend.events.add(const AudioSignal(
          progressOnly: true,
          position: Duration(seconds: 70),
          duration: Duration(seconds: 100)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(scroll.offset, closeTo(manual, 1));
      await tester.tap(find.text('Resume auto-scroll'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(manual));
      await tester.tap(find.text('Auto-scroll on'));
      await tester.runAsync(db.load);
      await tester.pumpAndSettle();
      expect(find.text('Auto-scroll off'), findsOneWidget);
      final disabled = scroll.offset;
      backend.events.add(const AudioSignal(
          progressOnly: true,
          position: Duration(seconds: 90),
          duration: Duration(seconds: 100)));
      await tester.pumpAndSettle();
      expect(scroll.offset, closeTo(disabled, 1));
      expect((await tester.runAsync(db.load))!.preferences['audioFollow'],
          'false');
      await tester.runAsync(db.load);
      await tester.pumpAndSettle();
      expect(
          (await tester.runAsync(db.load))!.history.single.completed, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
