import 'package:flutter_test/flutter_test.dart';
import 'package:selah/data/bible.dart';
import 'package:selah/data/xml_translation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Bible canon;
  late String source;
  setUpAll(() async {
    canon = await Bible.load();
    source =
        '<bible>${List.generate(66, (b) => '<book number="${b + 1}">${List.generate(canon.books[b].chapters.length, (c) => '<chapter number="${c + 1}"><verse number="1">Passage</verse><verse number="2"></verse><verse number="4">Another passage</verse><verse number="20">Before omission</verse><verse number="21"></verse><verse number="22">After omission</verse></chapter>').join()}</book>').join()}</bible>';
  });
  Bible parse(String text) => parseXmlTranslation(
      text, canon, 'test', 'Test Bible', 'TEST', 'Cebuano', 'Test attribution');

  test(
      'Merged ranges preserve references without crossing absent nodes or omissions',
      () {
    final bible = parse(source);
    expect(bible.verse('GEN.6.2').number, '1-2');
    expect(bible.verse('GEN.6.2').text, 'Passage');
    expect(bible.books.first.chapters.first.map((v) => v.number),
        ['1-2', '4', '20-21', '22']);
    expect(bible.books[39].chapters[16].map((v) => v.number),
        ['1-2', '4', '20', '22']);
    expect(bible.books.length, 66);
  });

  test('Invalid numbering, empty chapters and entity declarations are rejected',
      () {
    expect(() => parse(source.replaceFirst('number="2"', 'number="1"')),
        throwsFormatException);
    expect(
        () => parse(source
            .replaceFirst('>Passage<', '><')
            .replaceFirst('>Another passage<', '><')
            .replaceFirst('>Before omission<', '><')
            .replaceFirst('>After omission<', '><')),
        throwsFormatException);
    expect(() => parse('<!DOCTYPE bible>$source'), throwsFormatException);
  });
}
