// Metadata only: no audio is downloaded or bundled.
const fs = require('node:fs');
async function main() {
  const response = await fetch('https://archive.org/metadata/cebuanobiblemp3');
  if (!response.ok) throw Error(`Archive metadata ${response.status}`);
  const metadata = await response.json();
  const books = JSON.parse(fs.readFileSync('assets/bible/cebocb.json', 'utf8')).books.slice(39);
  const chapters = {};
  const files = metadata.files.filter(f => f.name.endsWith('.mp3'));
  if (files.length !== 260) throw Error('Expected 260 NT recordings');
  for (const file of files) {
    const match = /^B(\d{2})___(\d{2})_[A-Za-z0-9_]+_N2CEBRPV\.mp3$/.exec(file.name);
    if (!match) throw Error(`Unexpected filename ${file.name}`);
    const book = books[Number(match[1]) - 1];
    const chapter = Number(match[2]);
    if (!book || chapter < 1 || chapter > book.chapters.length) throw Error('Invalid reference');
    const ref = `${book.id}.${chapter}`;
    if (chapters[ref]) throw Error('Duplicate reference');
    chapters[ref] = `https://archive.org/download/cebuanobiblemp3/${file.name}`;
  }
  for (const book of books) for (let c = 1; c <= book.chapters.length; c++) {
    if (!chapters[`${book.id}.${c}`]) throw Error('Missing NT chapter');
  }
  fs.writeFileSync('assets/audio/mbbceb99.json', JSON.stringify({
    translation: 'mbbceb99', narrator: 'Faith Comes By Hearing — Cebuano audio drama',
    source: 'https://archive.org/details/cebuanobiblemp3',
    license: 'Recording attributed to Faith Comes By Hearing (Hosanna). Cebuano Revised Popular Version text © 1999 Philippine Bible Society. The third-party Internet Archive upload supplies no explicit reuse license; availability is not a permission grant. https://www.faithcomesbyhearing.com/bible-brain/license',
    editionNote: 'CEBRPV New Testament recordings paired with MBBCEB99. Exact wording may differ from the supplied text file. Streaming requires internet. Old Testament uses device TTS. Auto-scroll estimates chapter progress; there are no verse timestamps.',
    chapters,
  }, null, 2) + '\n');
  console.log(`Mapped ${Object.keys(chapters).length} New Testament chapters; no audio bundled.`);
}
main().catch(e => { console.error(e.message); process.exitCode = 1; });
