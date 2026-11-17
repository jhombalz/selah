import 'package:sqlite3/wasm.dart';

Future<WasmSqlite3>? _engine;
Future<CommonSqlite3> importSqliteEngine() async {
  try {
    return await (_engine ??=
        WasmSqlite3.loadFromUrl(Uri.base.resolve('sqlite3_import.wasm')));
  } catch (_) {
    _engine = null;
    rethrow;
  }
}
