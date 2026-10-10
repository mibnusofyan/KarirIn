import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// The user's CV file, kept only in the app's private storage on this device (never on the server).
class CvStorage {
  const CvStorage();

  Future<Directory> _dir() async => Directory('${(await getApplicationDocumentsDirectory()).path}/cv');

  /// Replaces any stored CV with [bytes].
  Future<void> save(List<int> bytes, String extension) async {
    final dir = await _dir();
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    await File('${dir.path}/cv.$extension').writeAsBytes(bytes, flush: true);
  }

  Future<bool> exists() async {
    final dir = await _dir();
    return await dir.exists() && await dir.list().isEmpty == false;
  }

  Future<void> delete() async {
    final dir = await _dir();
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
