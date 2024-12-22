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
}