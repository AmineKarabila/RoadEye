import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'camera_screen.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}



class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({super.key, required this.cameras});



  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoadEye',
      theme: ThemeData.dark(),
      home: CameraScreen(cameras: cameras),
    );
  }
  
  Future<Directory> _getPersistentDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final persistentDir = Directory('${directory.path}/RoadEyeData');
    
    if (!await persistentDir.exists()) {
      await persistentDir.create(recursive: true);
    }
    
    return persistentDir;
}

}
