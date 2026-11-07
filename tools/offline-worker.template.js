'use strict';
const CACHE = 'the-bible-shell-__CACHE_VERSION__';
const FILES = __PRECACHE_FILES__;
const urls = new Set(FILES.map(file => new URL(file, self.registration.scope).href));

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    try {
      await cache.addAll([...urls].map(url => new Request(url, {cache: 'reload'})));
    } catch (error) {
      await caches.delete(CACHE);
      throw error;
    }
    // Updates wait for existing app tabs to close, avoiding mixed app versions.
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) {
      if (key.startsWith('the-bible-shell-') && key !== CACHE) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  const scope = new URL(self.registration.scope);
  if (url.origin !== scope.origin || !url.pathname.startsWith(scope.pathname)) return;
  // Never cache audio, translation archives, or unrelated requests.
  const key = url.origin + url.pathname;
  if (event.request.mode === 'navigate') {
    event.respondWith((async () => {
      const cache = await caches.open(CACHE);
      return (await cache.match(new URL('index.html', scope).href)) || fetch(event.request);
    })());
  } else if (urls.has(key)) {
    event.respondWith((async () => {
      const cache = await caches.open(CACHE);
      return (await cache.match(key)) || fetch(event.request);
    })());
  }
});
