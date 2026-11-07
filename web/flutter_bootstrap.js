{{flutter_js}}
{{flutter_build_config}}

// The release build tool generates the offline worker. Flutter's deprecated
// worker is deliberately not registered; development remains uncached.
if ('serviceWorker' in navigator && window.isSecureContext) {
  navigator.serviceWorker.register('offline-worker.js').catch(error => {
    console.warn('Offline preparation is unavailable:', error);
  });
}
_flutter.loader.load();
