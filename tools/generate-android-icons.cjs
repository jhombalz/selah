const fs = require('node:fs');
const path = require('node:path');
const {spawn} = require('node:child_process');
const root = path.resolve(__dirname, '..');
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

async function main() {
  const profile = path.join(root, '.tools', 'android-icon-render-profile');
  const active = path.join(profile, 'DevToolsActivePort');
  try { fs.unlinkSync(active); } catch (error) { if (error.code !== 'ENOENT') throw error; }
  const executable = process.env.CHROME_EXECUTABLE || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
  const chrome = spawn(executable, ['--headless=new', '--no-first-run',
    '--no-default-browser-check', '--remote-debugging-port=0',
    `--user-data-dir=${profile}`, 'about:blank'], {windowsHide: true, stdio: 'ignore'});
  let socket;
  try {
    let port;
    for (let i = 0; i < 100; i++) {
      try { port = fs.readFileSync(active, 'utf8').split('\n')[0]; break; } catch {}
      await sleep(100);
    }
    if (!port) throw Error('Chrome did not start; check CHROME_EXECUTABLE.');
    const pages = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
    socket = new WebSocket(pages.find(page => page.type === 'page').webSocketDebuggerUrl);
    await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject; });
    let id = 0;
    const send = (method, params = {}) => new Promise((resolve, reject) => {
      const request = ++id;
      const listener = event => {
        const result = JSON.parse(event.data);
        if (result.id !== request) return;
        socket.removeEventListener('message', listener);
        result.error ? reject(Error(JSON.stringify(result.error))) : resolve(result.result);
      };
      socket.addEventListener('message', listener);
      socket.send(JSON.stringify({id: request, method, params}));
    });
    const svg = fs.readFileSync(path.join(root, 'android/branding/selah-mark.svg')).toString('base64');
    const result = await send('Runtime.evaluate', {awaitPromise: true, returnByValue: true,
      expression: `(async () => {
        const image = new Image(); image.src = 'data:image/svg+xml;base64,${svg}'; await image.decode();
        const result = {};
        for (const size of [48, 72, 96, 144, 192]) {
          for (const round of [false, true]) {
            const canvas = document.createElement('canvas'); canvas.width = canvas.height = size;
            const context = canvas.getContext('2d');
            if (round) { context.beginPath(); context.arc(size/2, size/2, size/2, 0, Math.PI*2); context.clip();
              context.fillStyle = '#244b3e'; context.fillRect(0, 0, size, size); }
            context.drawImage(image, 0, 0, size, size);
            result[size + (round ? '-round' : '')] = canvas.toDataURL('image/png').split(',')[1];
          }
        }
        return result;
      })()`});
    if (result.exceptionDetails || !result.result.value) throw Error('Icon rendering failed.');
    for (const [density, size] of Object.entries({mdpi:48, hdpi:72, xhdpi:96, xxhdpi:144, xxxhdpi:192})) {
      const directory = path.join(root, 'android/app/src/main/res', `mipmap-${density}`);
      fs.mkdirSync(directory, {recursive:true});
      fs.writeFileSync(path.join(directory, 'ic_launcher.png'), Buffer.from(result.result.value[size], 'base64'));
      fs.writeFileSync(path.join(directory, 'ic_launcher_round.png'), Buffer.from(result.result.value[`${size}-round`], 'base64'));
    }
    const exited = new Promise(resolve => chrome.once('exit', resolve));
    socket.send(JSON.stringify({id:++id, method:'Browser.close'}));
    await exited;
    console.log('Generated 10 SELAH launcher icons for Android. Web assets unchanged.');
  } finally {
    socket?.close();
    if (chrome.exitCode === null) chrome.kill();
  }
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
