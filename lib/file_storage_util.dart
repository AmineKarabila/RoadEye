import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileStorageUtil {
  static Future<Directory> getPersistentDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final persistentDir = Directory('${directory.path}/RoadEyeData');

    if (!await persistentDir.exists()) {
      await persistentDir.create(recursive: true);
    }

    return persistentDir;
  }

  static Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
      print('Datei gelöscht: $filePath');
    } else {
      print('Datei nicht gefunden: $filePath');
    }
  }
}