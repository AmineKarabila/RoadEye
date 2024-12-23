import 'package:flutter/material.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:convert';
import 'file_storage_util.dart';


class VideoPlayerScreen extends StatefulWidget {
  final File videoFile;

  const VideoPlayerScreen({super.key, required this.videoFile});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  List<LatLng> _loadedRoute = [];
  
  
  @override
  void initState() {
    super.initState();
    _loadRoute();
    _controller = VideoPlayerController.file(widget.videoFile)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  Future<void> _loadRoute() async {
    final persistentDir = await FileStorageUtil.getPersistentDirectory(); // Korrekt: Persistent Directory verwenden
    final routePath = '${persistentDir.path}/${widget.videoFile.path.split('/').last}_route.json';
    final file = File(routePath);

    if (!await file.exists()) {
      print('Route-Datei nicht gefunden: $routePath');
      return;
    }

    print('Lade Route-Datei: $routePath'); // Debugging-Log

    final routeData = jsonDecode(await file.readAsString()) as List;
    setState(() {
      _loadedRoute = routeData
          .map((coord) =>
              LatLng(coord['latitude'] as double, coord['longitude'] as double))
          .toList();
    });
  }

  void _showMapPopup() {
    if (_loadedRoute.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Keine Route für dieses Video verfügbar.")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Route anzeigen'),
        content: SizedBox(
          height: 300,
          width: 300,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _loadedRoute.first,
              zoom: 14,
            ),
            polylines: {
              Polyline(
                polylineId: PolylineId('route'),
                points: _loadedRoute,
                color: Colors.blue,
                width: 4,
              ),
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Schließen'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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


@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text("Video Player"),
    ),
    body: Stack(
      children: [
        Center(
          child: _controller.value.isInitialized
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                )
              : const CircularProgressIndicator(),
        ),
        Positioned(
          right: 10,
          top: 50,
          child: Column(
            children: [
              IconButton(
                onPressed: _showMapPopup,
                icon: const Icon(
                  Icons.map,
                  color: Colors.white,
                ),
                iconSize: 30.0,
                tooltip: "Route anzeigen",
              ),
              const SizedBox(height: 20), // Abstand
              IconButton(
                onPressed: () async {
                  // Video und Route löschen
                  await FileStorageUtil.deleteFile(widget.videoFile.path);
                  final persistentDir =
                      await FileStorageUtil.getPersistentDirectory();
                  final routePath =
                      '${persistentDir.path}/${widget.videoFile.path.split('/').last}_route.json';
                  final routeFile = File(routePath);
                  if (await routeFile.exists()) {
                    await routeFile.delete();
                  }
                  // Navigation zurück zur Hauptseite
                  Navigator.pushReplacementNamed(context, '/');
                },
                icon: const Icon(
                  Icons.delete,
                  color: Colors.red,
                ),
                iconSize: 30.0,
                tooltip: "Löschen",
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
  //----


}