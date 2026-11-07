import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/data/bible.dart';
import 'package:selah/data/user_backup.dart';
import 'package:selah/data/user_database.dart';
import 'package:selah/features/backup/backup_files.dart';
import 'package:selah/features/backup/backup_page.dart';

class FakeBackupFiles implements BackupFiles {
  PickedBackup? picked;
  Uint8List? exported;
  @override
  Future<PickedBackup?> pick() async => picked;
  @override
  Future<bool> save(String filename, Uint8List bytes) async {
    exported = bytes;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Bible canon;
  setUpAll(() async => canon = await Bible.load());

  testWidgets(
      'Export produces a readable backup and cancelled file selection changes nothing',
      (tester) async {
    final files = FakeBackupFiles();
    int restores = 0;
    final backup = UserBackup.create(
        const UserData(notes: {'GEN.1.1': 'My reflection'}), canon);
    await tester.pumpWidget(MaterialApp(
        home: BackupPage(
            canon: canon,
            files: files,
            capture: () async => backup,
            restore: (selected, mode) async {
              restores++;
              return RestoreResult(selected.data, false);
            })));
    await tester.tap(find.text('Export backup'));
    await tester.pumpAndSettle();
    expect(UserBackup.decode(files.exported!, canon).data.notes['GEN.1.1'],
        'My reflection');
    await tester.tap(find.text('Choose backup file'));
    await tester.pumpAndSettle();
    expect(restores, 0);
    expect(find.text('Backup preview'), findsNothing);
  });

  testWidgets('Restore previews counts and replacement requires confirmation',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final backup = UserBackup.create(
        const UserData(notes: {'GEN.1.1': 'My reflection'}), canon);
    final files = FakeBackupFiles()
      ..picked = PickedBackup('backup.json', backup.encode());
    int restores = 0;
    await tester.pumpWidget(MaterialApp(
        home: BackupPage(
            canon: canon,
            files: files,
            capture: () async => backup,
            restore: (selected, mode) async {
              restores++;
              expect(mode, RestoreMode.replace);
              return RestoreResult(selected.data, false);
            })));
    await tester.tap(find.text('Choose backup file'));
    await tester.pumpAndSettle();
    expect(find.text('Backup preview'), findsOneWidget);
    expect(find.textContaining('1 notes'), findsOneWidget);
    expect(restores, 0);
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Replace with backup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace with backup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(restores, 0);
    await tester.tap(find.text('Replace with backup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace data'));
    await tester.pumpAndSettle();
    expect(restores, 1);
    expect(find.text('Backup preview'), findsNothing);
  });
}
