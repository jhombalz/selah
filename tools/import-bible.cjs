// Reproducible import from eBible's VPL text, with verse ranges from USFX.
const fs = require('node:fs');
const crypto = require('node:crypto');
const source = '.tools/bible-source/cebocb_vpl.txt';
const usfx = fs.readFileSync('.tools/bible-usfx/cebocb_usfx.xml', 'utf8');
const names = fs.readFileSync('.tools/bible-usfx/BookNames.xml', 'utf8');
const labels = new Map([...usfx.matchAll(/<v id="([^"]+)" bcv="([^"]+)"\s*\/>/g)].map(m => [m[2], m[1]]));
const catalog = [...names.matchAll(/<book code="([^"]+)"[^>]* short="([^"]+)"/g)].map(m => ({id:m[1],name:m[2],chapters:[]}));
const byId = new Map(catalog.map(b => [b.id,b]));
const seen = new Set();
let count = 0;
for (const line of fs.readFileSync(source,'utf8').split(/\r?\n/)) {
  if (!line.trim()) continue;
  const match = /^(\w+) (\d+):(\d+) (.+)$/.exec(line);
  if (!match) throw Error('Unrecognized VPL row');
  const [,rawId,c,v,text] = match;
  const id = ({SOL:'SNG',EZE:'EZK',JOE:'JOL',NAH:'NAM',MAR:'MRK',JOH:'JHN',PHI:'PHP',JAM:'JAS','1JO':'1JN','2JO':'2JN','3JO':'3JN'})[rawId] || rawId;
  const key = `${id}.${c}.${v}`;
  if (seen.has(key)) throw Error(`Duplicate ${key}`);
  seen.add(key);
  const label = labels.get(key);
  if (!label || !/^\d+(-\d+)?$/.test(label)) throw Error(`Missing/invalid verse label ${key}`);
  const chapter = +c;
  const book = byId.get(id);
  if (!book) throw Error(`Unknown book ${id}`);
  while (book.chapters.length < chapter) book.chapters.push([]);
  book.chapters[chapter-1].push({number:label,text});
  count++;
}
if (catalog.length !== 66 || labels.size !== count) throw Error('Incomplete Bible');
const chapters = catalog.reduce((sum,b) => sum+b.chapters.length,0);
if (chapters !== 1189 || catalog.some(b => b.chapters.some(c => !c.length))) throw Error('Incomplete chapters');
const bible = {id:'cebocb',title:'Biblica® Open Ang Pulong sa Dios™',language:'Cebuano',license:'CC BY-SA 4.0',books:catalog};
fs.writeFileSync('assets/bible/cebocb.json',JSON.stringify(bible));
const copyright = fs.readFileSync('assets/bible/copyright.html','utf8');
const decode = s => s.replace(/&nbsp;/g,' ').replace(/&amp;/g,'&').replace(/&quot;/g,'"').replace(/&#39;/g,"'");
const body = copyright.slice(copyright.indexOf('<h1'));
const notice = decode(body.replace(/<script[\s\S]*?<\/script>/g,'').replace(/<[^>]+>/g,'\n')).split('\n').map(s=>s.trim()).filter(Boolean).filter(s=>s!=='Go!' && s!=='^' && s!=='<' && s!=='>').join('\n\n');
fs.writeFileSync('assets/bible/LICENSE.txt',`${notice}\n\nThe original Work by its copyright holders is available for free at www.biblica.com and open.bible.\n\nSELAH packaging: text imported from the eBible VPL export; USFX verse-range labels preserved. Formatting and noncanonical headings/footnotes are not included. Scripture wording has not been edited.\n`);
fs.writeFileSync('assets/bible/provenance.json',JSON.stringify({
  source:'https://ebible.org/Scriptures/cebocb_vpl.zip',
  rangeSource:'https://ebible.org/Scriptures/cebocb_usfx.zip',
  copyrightSource:'https://ebible.org/cebocb/copyright.htm',
  sourceDate:'2025-04-30',importDate:'2026-11-07',books:66,chapters,verseEntries:count,
  sourceSha256:crypto.createHash('sha256').update(fs.readFileSync(source)).digest('hex'),
  outputSha256:crypto.createHash('sha256').update(fs.readFileSync('assets/bible/cebocb.json')).digest('hex'),
},null,2));
console.log(`Imported ${catalog.length} books, ${chapters} chapters, ${count} verse entries.`);
