// Generate bundled reading metadata from AO Lab's structured, licensed editions.
// Run explicitly after reviewing source changes; normal builds use committed assets.
const fs = require('node:fs');
const crypto = require('node:crypto');
const zlib = require('node:zlib');
const editions = {cebocb:'ceb_ocb', bsb:'BSB', kjv:'eng_kjv'};
function usfmTexts(zip) {
  let end = zip.length - 22;
  while (end >= Math.max(0, zip.length - 65557) && zip.readUInt32LE(end) !== 0x06054b50) end--;
  if (end < 0) throw Error('Invalid source archive');
  const texts = [];
  let cursor = zip.readUInt32LE(end + 16);
  for (let i=0; i<zip.readUInt16LE(end+10); i++) {
    if (zip.readUInt32LE(cursor) !== 0x02014b50) throw Error('Invalid source entry');
    const size=zip.readUInt32LE(cursor+20), nameSize=zip.readUInt16LE(cursor+28);
    const name=zip.toString('utf8',cursor+46,cursor+46+nameSize);
    if (/\.(usfm|sfm)$/i.test(name)) {
      const start=zip.readUInt32LE(cursor+42);
      const offset=start+30+zip.readUInt16LE(start+26)+zip.readUInt16LE(start+28);
      const bytes=zip.subarray(offset,offset+size);
      texts.push((zip.readUInt16LE(cursor+10)===8?zlib.inflateRawSync(bytes):bytes).toString('utf8'));
    }
    cursor+=46+nameSize+zip.readUInt16LE(cursor+30)+zip.readUInt16LE(cursor+32);
  }
  return texts;
}
async function main() {
  fs.mkdirSync('assets/bible/formatting', {recursive:true});
  for (const [local, remote] of Object.entries(editions)) {
    const url = `https://bible.helloao.org/api/${remote}/complete.json`;
    const snapshot = `.tools/${remote}-structured.json`;
    const bytes = process.argv.includes('--snapshots') && fs.existsSync(snapshot)
      ? fs.readFileSync(snapshot)
      : Buffer.from(await (await fetch(url, {signal:AbortSignal.timeout(90000)})).arrayBuffer());
    const data = JSON.parse(bytes);
    if (data.translation.id !== remote || data.books.length !== 66) throw Error('Unexpected edition');
    const entries = {};
    for (const book of data.books) for (const item of book.chapters) {
      const chapter = item.chapter;
      let headings = [], paragraph = true;
      for (const row of chapter.content) {
        if (row.type === 'heading') { headings.push(row.content.join(' ')); paragraph = true; continue; }
        if (row.type === 'line_break') { paragraph = true; continue; }
        if (row.type !== 'verse') continue;
        const segments = [], notes = [];
        const append = value => {
          const text = typeof value === 'string' ? value : value.text;
          const last = segments.at(-1);
          const before = typeof last === 'string' ? last : last?.text || '';
          if (/[\p{L}\p{N},;:.!?]$/u.test(before) && /^[\p{L}\p{N}“‘]/u.test(text)) segments.push(' ');
          segments.push(value);
        };
        for (const part of row.content) {
          if (typeof part === 'string') append(part);
          else if (typeof part.text === 'string') append(part.wordsOfJesus === true
            ? {text:part.text, jesus:true} : part.text);
          else if (part.noteId !== undefined) {
            const note = chapter.footnotes.find(n=>n.noteId === part.noteId);
            if (note?.text) notes.push(note.text);
          } else if (part.lineBreak) segments.push('\n');
          else if (part.heading) headings.push(part.heading);
        }
        const text = segments.map(s=>typeof s==='string'?s:s.text).join('');
        entries[`${book.id}.${chapter.number}.${row.number}`] = {
          text, ...(headings.length?{headings}:{}), ...(paragraph?{paragraph:true}:{}),
          ...(notes.length?{notes}:{}),
          ...(segments.some(s=>s.jesus)?{segments}:{})
        };
        headings = []; paragraph = false;
      }
    }
    const result = {version:1, translation:local, source:url,
      sourceSha256:crypto.createHash('sha256').update(bytes).digest('hex'),
      license:data.translation.licenseUrl, entries};
    if (local === 'bsb') {
      const zipUrl='https://ebible.org/Scriptures/engbsb_usfm.zip';
      const zip=process.argv.includes('--snapshots') && fs.existsSync('.tools/bsb-usfm.zip')
        ? fs.readFileSync('.tools/bsb-usfm.zip')
        : Buffer.from(await (await fetch(zipUrl,{signal:AbortSignal.timeout(60000)})).arrayBuffer());
      for (const usfm of usfmTexts(zip)) {
        const book=/\\id (\w+)/.exec(usfm)?.[1];
        let chapter=0, references=[];
        for (const line of usfm.split(/\r?\n/)) {
          if (/^\\c (\d+)/.test(line)) chapter=Number(/^\\c (\d+)/.exec(line)[1]);
          if (/^\\s\d? /.test(line)) references=[];
          if (/^\\r /.test(line)) references.push(...line.slice(3).trim().replace(/^\(|\)$/g,'').split(/;\s*/));
          const verse=/^\\v (\d+)/.exec(line);
          if (verse && references.length) {
            const entry=entries[`${book}.${chapter}.${verse[1]}`];
            if(entry) entry.crossReferences=references;
            references=[];
          }
        }
      }
      result.crossReferenceSource=zipUrl;
      result.crossReferenceSourceSha256=crypto.createHash('sha256').update(zip).digest('hex');
    }
    fs.writeFileSync(`assets/bible/formatting/${local}.json`, JSON.stringify(result));
    console.log(`${local}: ${Object.keys(entries).length} verses`);
  }
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
