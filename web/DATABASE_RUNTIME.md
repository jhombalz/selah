# Browser database runtime

`drift_worker.js` and `sqlite3.wasm` are matching files from Drift 2.35.3:
https://github.com/simolus3/drift/releases/tag/drift-2.35.3

They are shipped locally so the database does not depend on a CDN at runtime.
Update both when upgrading the locked Drift runtime. Serve the Wasm file with
`Content-Type: application/wasm`; Flutter's development server does this.

Drift license: https://github.com/simolus3/drift/blob/drift-2.35.3/LICENSE
sqlite3 Dart bindings license: https://github.com/simolus3/sqlite3.dart/blob/main/sqlite3/LICENSE
SQLite copyright: https://sqlite.org/copyright.html

Flutter's generated third-party license notices include package licenses.
Browser persistence has been tested in Chrome; other browsers and mobile
device builds still need validation.
