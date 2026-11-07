import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selah/data/user_database.dart';

void main() {
  test(
      'Annotations, settings, history and explicit completion survive reopening',
      () async {
    final directory = await Directory.systemTemp.createTemp('selah-db-test-');
    final file = File('${directory.path}/user.sqlite');
    var database = UserDatabase(NativeDatabase(file));
    try {
      await database.setBookmark('GEN.1.17-18', true);
      await database.setNote('GEN.1.17-18', 'Salamat, Ginoo! “Kahayag”');
      await database.setHighlight('GEN.1.17-18', 0xffffc107);
      await database.setPreferences({'dark': 'true', 'fontSize': '26'});
      await database.visit('GEN.1');
      await database.setCompleted('GEN.1', true);
      await database.visit('JHN.3', offset: 450);
      await database.close();
      database = UserDatabase(NativeDatabase(file));
      final data = await database.load();
      expect(data.bookmarks, {'GEN.1.17-18'});
      expect(data.notes['GEN.1.17-18'], 'Salamat, Ginoo! “Kahayag”');
      expect(data.highlights['GEN.1.17-18'], 0xffffc107);
      expect(data.preferences['lastChapter'], 'JHN.3');
      expect(data.preferences['scrollOffset'], '450.0');
      expect(data.preferences['dark'], 'true');
      expect(data.preferences['fontSize'], '26');
      expect(data.history.singleWhere((r) => r.reference == 'GEN.1').completed,
          isTrue);
      expect(data.history.singleWhere((r) => r.reference == 'JHN.3').completed,
          isFalse);
      await database.visit('GEN.1');
      expect(
          (await database.load())
              .history
              .singleWhere((r) => r.reference == 'GEN.1')
              .completed,
          isTrue);
      await database.setBookmark('GEN.1.17-18', false);
      await database.setHighlight('GEN.1.17-18', null);
      final edited = await database.load();
      expect(edited.bookmarks, isEmpty);
      expect(edited.highlights, isEmpty);
      expect(edited.notes, isNotEmpty);
      await database.setNote('GEN.1.17-18', null);
      expect((await database.load()).notes, isEmpty);
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });
}
