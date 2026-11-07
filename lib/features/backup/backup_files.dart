import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../../data/user_backup.dart';

class PickedBackup {
  final String name;
  final Uint8List bytes;
  const PickedBackup(this.name, this.bytes);
}

abstract class BackupFiles {
  Future<bool> save(String filename, Uint8List bytes);
  Future<PickedBackup?> pick();
}

class DeviceBackupFiles implements BackupFiles {
  @override
  Future<bool> save(String filename, Uint8List bytes) async {
    final result = await FilePicker.saveFile(
        fileName: filename,
        bytes: bytes,
        mimeType: 'application/json',
        dialogTitle: 'Save Bible backup');
    // Browsers cannot report whether an initiated download was retained.
    return kIsWeb || result != null;
  }

  @override
  Future<PickedBackup?> pick() async {
    final file = await FilePicker.pickFile(
        dialogTitle: 'Choose a Bible backup',
        type: FileType.custom,
        allowedExtensions: ['json']);
    if (file == null) return null;
    final length = file.lengthSync();
    if (length != null && length > UserBackup.maxBytes) {
      throw const FormatException('Choose a backup file smaller than 10 MB.');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.readAsByteStream()) {
      bytes.add(chunk);
      if (bytes.length > UserBackup.maxBytes) {
        throw const FormatException('Choose a backup file smaller than 10 MB.');
      }
    }
    return PickedBackup(file.name, bytes.takeBytes());
  }
}
