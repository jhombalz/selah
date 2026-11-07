import 'dart:convert';
import 'package:flutter/services.dart';

class BibleVerse {
  final String number;
  final String text;
  const BibleVerse(this.number, this.text);
}

class BibleBook {
  final String id;
  final String name;
  final List<List<BibleVerse>> chapters;
  const BibleBook(this.id, this.name, this.chapters);
}

/// Read-only bundled Scripture; no network access or database is needed to read.
class Bible {
  final List<BibleBook> books;
  final String title;
  final String id;
  final String abbreviation;
  final String language;
  final String licenseText;
  const Bible(this.books, this.title,
      {this.id = 'cebocb',
      this.abbreviation = 'OCCB',
      this.language = 'Cebuano',
      this.licenseText = ''});

  static Future<Bible> load() async {
    return fromJson(
        jsonDecode(await rootBundle.loadString('assets/bible/cebocb.json'))
            as Map<String, dynamic>);
  }

  static Bible fromJson(Map<String, dynamic> data) {
    final books = (data['books'] as List).map((item) {
      final book = item as Map<String, dynamic>;
      return BibleBook(
          book['id'] as String,
          book['name'] as String,
          (book['chapters'] as List)
              .map((chapter) => (chapter as List)
                  .map((v) =>
                      BibleVerse(v['number'] as String, v['text'] as String))
                  .toList())
              .toList());
    }).toList();
    return Bible(books, data['title'] as String,
        id: data['id'] as String? ?? 'cebocb',
        abbreviation: data['abbreviation'] as String? ?? 'OCCB',
        language: data['language'] as String? ?? 'Cebuano',
        licenseText: data['licenseText'] as String? ?? '');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'abbreviation': abbreviation,
        'language': language,
        'licenseText': licenseText,
        'books': [
          for (final book in books)
            {
              'id': book.id,
              'name': book.name,
              'chapters': [
                for (final chapter in book.chapters)
                  [
                    for (final verse in chapter)
                      {'number': verse.number, 'text': verse.text}
                  ]
              ]
            }
        ]
      };

  static bool overlaps(String a, String b) {
    final left = a.split('.');
    final right = b.split('.');
    if (left.length != 3 ||
        right.length != 3 ||
        left[0] != right[0] ||
        left[1] != right[1]) {
      return false;
    }
    final l = left[2].split('-').map(int.parse).toList();
    final r = right[2].split('-').map(int.parse).toList();
    return l.first <= r.last && r.first <= l.last;
  }

  String reference(String key) {
    final parts = key.split('.');
    final book = books.firstWhere((b) => b.id == parts[0]);
    return '${book.name} ${parts[1]}:${parts[2]}';
  }

  BibleVerse verse(String key) {
    final parts = key.split('.');
    final chapter = books
        .firstWhere((b) => b.id == parts[0])
        .chapters[int.parse(parts[1]) - 1];
    for (final verse in chapter) {
      if (verse.number == parts[2]) return verse;
    }
    final matches = chapter
        .where((v) => overlaps(key, '${parts[0]}.${parts[1]}.${v.number}'))
        .toList();
    if (matches.isEmpty) {
      return BibleVerse(
          parts[2], 'This passage is not present in the selected translation.');
    }
    return BibleVerse(matches.length == 1 ? matches.first.number : parts[2],
        matches.map((v) => v.text).join(' '));
  }
}
