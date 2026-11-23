// Файл: lib/database/file_service.dart

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class FileService {
  FileService._();
  static final FileService instance = FileService._();

  static const String _attachmentsFolder = 'habitkeep_attachments';

  Future<Directory> _getAttachmentsDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(p.join(appDocDir.path, _attachmentsFolder));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    return targetDir;
  }

  Future<String> saveFilePermanently({
    required String sourcePath,
    required String originalFileName,
  }) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) return sourcePath;

    final dir = await _getAttachmentsDirectory();

    if (p.isWithin(dir.path, sourcePath)) return sourcePath;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitizedName =
    originalFileName.replaceAll(RegExp(r'[^\w\.\-]'), '_');
    final uniqueFileName = '${timestamp}_$sanitizedName';
    final destinationPath = p.join(dir.path, uniqueFileName);

    final copiedFile = await sourceFile.copy(destinationPath);
    return copiedFile.path;
  }

  Future<void> deletePhysicalFile(String filePath) async {
    if (filePath.trim().isEmpty) return;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<void> deleteMultipleFiles(Iterable<String> filePaths) async {
    for (final path in filePaths) {
      await deletePhysicalFile(path);
    }
  }
}