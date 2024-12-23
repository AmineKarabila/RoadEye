import 'package:flutter/material.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Timeline
                VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: Colors.red,
                    bufferedColor: Colors.grey,
                    backgroundColor: Colors.black,
                  ),
                ),
                const SizedBox(height: 20), // Größerer Abstand
                // Steuerungselemente
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // -10 Sekunden Button
                    IconButton(
                      onPressed: () {
                        final currentPosition = _controller.value.position;
                        final newPosition = currentPosition - const Duration(seconds: 10);
                        _controller.seekTo(newPosition > Duration.zero ? newPosition : Duration.zero);
                      },
                      icon: const Icon(Icons.replay_10, size: 60, color: Colors.white), // Größer gemacht
                    ),
                    // Play/Pause Button
                    IconButton(
                      onPressed: () {
                        setState(() {
                          if (_controller.value.isPlaying) {
                            _controller.pause();
                          } else {
                            _controller.play();
                          }
                        });
                      },
                      icon: Icon(
                        _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 60, // Größer gemacht
                        color: Colors.white,
                      ),
                    ),
                    // +10 Sekunden Button
                    IconButton(
                      onPressed: () {
                        final currentPosition = _controller.value.position;
                        final newPosition = currentPosition + const Duration(seconds: 10);
                        _controller.seekTo(newPosition < _controller.value.duration
                            ? newPosition
                            : _controller.value.duration);
                      },
                      icon: const Icon(Icons.forward_10, size: 60, color: Colors.white), // Größer gemacht
                    ),
                  ],
                ),
                const SizedBox(height: 20), // Größerer Abstand zum unteren Rand
              ],
            ),
          ),
        ],
      ),
    );
  }
}