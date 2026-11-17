// Metadata only: no audio is downloaded or bundled.
const fs = require('node:fs');
async function main() {
  const tagalog = process.argv.includes('--tagalog');
  const collection = tagalog ? 'tagalogbibleaudio' : 'cebuanobiblemp3';
  const id = tagalog ? 'mbb05' : 'mbbceb99';
  const code = tagalog ? 'TGLMBB' : 'CEBRPV';
  const response = await fetch(`https://archive.org/metadata/${collection}`);
  if (!response.ok) throw Error(`Archive metadata ${response.status}`);
  const metadata = await response.json();
  const books = JSON.parse(fs.readFileSync('assets/bible/cebocb.json', 'utf8')).books.slice(39);
  const chapters = {};
  const files = metadata.files.filter(f => f.name.endsWith('.mp3'));
  if (files.length !== 260) throw Error('Expected 260 NT recordings');
  for (const file of files) {
    const match = new RegExp(`^B(\\d{2})___(\\d{2})_[A-Za-z0-9_]+_N2${code}\\.mp3$`).exec(file.name);
    if (!match) throw Error(`Unexpected filename ${file.name}`);
    const book = books[Number(match[1]) - 1];
    const chapter = Number(match[2]);
    if (!book || chapter < 1 || chapter > book.chapters.length) throw Error('Invalid reference');
    const ref = `${book.id}.${chapter}`;
    if (chapters[ref]) throw Error('Duplicate reference');
    chapters[ref] = `https://archive.org/download/${collection}/${file.name}`;
  }
  for (const book of books) for (let c = 1; c <= book.chapters.length; c++) {
    if (!chapters[`${book.id}.${c}`]) throw Error('Missing NT chapter');
  }
  fs.writeFileSync(`assets/audio/${id}.json`, JSON.stringify({
    translation: id, narrator: `Faith Comes By Hearing — ${tagalog ? 'Tagalog' : 'Cebuano'} audio drama`,
    source: `https://archive.org/details/${collection}`,
    license: tagalog
      ? 'Recording attributed to Faith Comes By Hearing (Hosanna). Archive uploaded by The Bible Seeder, marked CC BY-NC-ND 3.0 Philippines: https://creativecommons.org/licenses/by-nc-nd/3.0/ph/ . Uploader labeling does not independently establish rights-holder authorization. Text © 2005 Philippine Bible Society.'
      : 'Recording attributed to Faith Comes By Hearing (Hosanna). Cebuano Revised Popular Version text © 1999 Philippine Bible Society. The third-party Internet Archive upload supplies no explicit reuse license; availability is not a permission grant. https://www.faithcomesbyhearing.com/bible-brain/license',
    editionNote: `${code} New Testament recordings paired with ${id.toUpperCase()}. Exact wording may differ from the supplied text file; word-for-word alignment has not been verified. Streaming requires internet. Old Testament uses device TTS. Auto-scroll estimates chapter progress; there are no verse timestamps.`,
    chapters,
  }, null, 2) + '\n');
  console.log(`Mapped ${Object.keys(chapters).length} New Testament chapters; no audio bundled.`);
}
main().catch(e => { console.error(e.message); process.exitCode = 1; });
