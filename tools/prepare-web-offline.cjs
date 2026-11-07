// Run after `flutter build web --no-web-resources-cdn`.
const fs = require('node:fs');
const path = require('node:path');
const {createHash} = require('node:crypto');
const root = path.resolve(process.argv[2] || 'build/web');
const required = ['index.html', 'main.dart.js', 'flutter_bootstrap.js',
  'flutter.js', 'manifest.json', 'sqlite3.wasm', 'drift_worker.js', 'selah-mark.svg', 'favicon.png'];
const files = [...required];
function walk(relative) {
  for (const entry of fs.readdirSync(path.join(root, relative), {withFileTypes:true})) {
    const file = `${relative}/${entry.name}`;
    if (entry.isDirectory()) walk(file);
    else if (!file.endsWith('.map') &&
        (!file.startsWith('canvaskit/') || /\/(chromium\/)?canvaskit\.(js|wasm)$/.test(file))) files.push(file);
  }
}
walk('assets');
walk('canvaskit');
walk('icons');
files.sort();
const hash = createHash('sha256');
let bytes = 0;
for (const file of files) {
  const data = fs.readFileSync(path.join(root, file));
  hash.update(file).update(data);
  bytes += data.length;
}
const bootstrap = fs.readFileSync(path.join(root, 'flutter_bootstrap.js'), 'utf8');
if (!bootstrap.includes('"useLocalCanvasKit":true')) throw Error('Rebuild with --no-web-resources-cdn for offline rendering.');
const template = fs.readFileSync(path.join(__dirname, 'offline-worker.template.js'), 'utf8');
const worker = template.replace('__CACHE_VERSION__', hash.digest('hex').slice(0, 20))
  .replace('__PRECACHE_FILES__', JSON.stringify(files));
fs.writeFileSync(path.join(root, 'offline-worker.js'), worker);
console.log(`Offline reader prepared: ${files.length} files, ${(bytes/1024/1024).toFixed(1)} MB. Translation ZIPs and audio excluded.`);
