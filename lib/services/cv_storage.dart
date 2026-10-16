import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// A CV file stored on this device.
class StoredCv {
  const StoredCv({required this.bytes, required this.extension, required this.savedAt});
  final Uint8List bytes;

  /// `pdf` or `jpg` (a photographed CV).
  final String extension;
  final DateTime savedAt;

  bool get isPdf => extension == 'pdf';
  String get mimeType => isPdf ? 'application/pdf' : 'image/jpeg';
}

/// The user's CV file, kept in the app's private storage on this device. The server only gets a copy when the user
/// sends a Lamar cepat application with it.
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

  /// The stored CV; null when there is none on this device (deleted, or the profile came from another device).
  Future<StoredCv?> load() async {
    final dir = await _dir();
    if (!await dir.exists()) return null;
    final files = await dir.list().where((e) => e is File).cast<File>().toList();
    if (files.isEmpty) return null;
    final file = files.first;
    return StoredCv(bytes: await file.readAsBytes(), extension: file.path.split('.').last, savedAt: await file.lastModified());
  }

  Future<void> delete() async {
    final dir = await _dir();
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

/// Mock builds: Rani's CV as a small placeholder PDF, held in memory.
class DemoCvStorage extends CvStorage {
  DemoCvStorage();

  StoredCv? _cv = StoredCv(
    bytes: Uint8List.fromList(utf8.encode('%PDF-1.4\n% CV demo Rani Lestari (KarirIn)\n%%EOF\n')),
    extension: 'pdf',
    savedAt: DateTime(2026, 10, 8),
  );

  @override
  Future<void> save(List<int> bytes, String extension) async =>
      _cv = StoredCv(bytes: Uint8List.fromList(bytes), extension: extension, savedAt: DateTime.now());

  @override
  Future<bool> exists() async => _cv != null;

  @override
  Future<StoredCv?> load() async => _cv;

  @override
  Future<void> delete() async => _cv = null;
}
