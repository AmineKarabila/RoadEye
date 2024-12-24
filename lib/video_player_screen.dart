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
        const SnackBar(content: Text("Keine Route für dieses Video verfügbar.")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0), // Abgerundete Ecken
          ),
          insetPadding: const EdgeInsets.all(16.0), // Padding um den Dialog
          child: Stack(
            children: [
              // Inhalt des Popups
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: MediaQuery.of(context).size.height * 0.6, // 60% der Bildschirmhöhe
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16.0),
                        topRight: Radius.circular(16.0),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16.0),
                        topRight: Radius.circular(16.0),
                      ),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _loadedRoute.first,
                          zoom: 14,
                        ),
                        polylines: {
                          Polyline(
                            polylineId: const PolylineId('route'),
                            points: _loadedRoute,
                            color: Colors.blue,
                            width: 4,
                          ),
                        },
                        markers: {
                          Marker(
                            markerId: const MarkerId('start'),
                            position: _loadedRoute.first,
                            infoWindow: const InfoWindow(title: 'Startpunkt'),
                          ),
                          Marker(
                            markerId: const MarkerId('end'),
                            position: _loadedRoute.last,
                            infoWindow: const InfoWindow(title: 'Zielpunkt'),
                          ),
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  const Text(
                    'Route anzeigen',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                ],
              ),
              // X-Button oben rechts
              Positioned(
                right: 8.0,
                top: 8.0,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
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
                iconSize: 40.0,
                tooltip: "Route anzeigen",
              ),
              const SizedBox(height: 20),
              IconButton(
                onPressed: () async {
                  await FileStorageUtil.deleteFile(widget.videoFile.path);
                  final persistentDir =
                      await FileStorageUtil.getPersistentDirectory();
                  final routePath =
                      '${persistentDir.path}/${widget.videoFile.path.split('/').last}_route.json';
                  final routeFile = File(routePath);
                  if (await routeFile.exists()) {
                    await routeFile.delete();
                  }
                  Navigator.pushReplacementNamed(context, '/');
                },
                icon: const Icon(
                  Icons.delete,
                  color: Colors.red,
                ),
                iconSize: 40.0,
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
              VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                colors: VideoProgressColors(
                  playedColor: Colors.red,
                  bufferedColor: Colors.grey,
                  backgroundColor: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      final currentPosition = _controller.value.position;
                      final newPosition = currentPosition - const Duration(seconds: 10);
                      _controller.seekTo(newPosition > Duration.zero ? newPosition : Duration.zero);
                    },
                    icon: const Icon(Icons.replay_10, size: 60, color: Colors.white),
                  ),
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
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      final currentPosition = _controller.value.position;
                      final newPosition = currentPosition + const Duration(seconds: 10);
                      _controller.seekTo(newPosition < _controller.value.duration
                          ? newPosition
                          : _controller.value.duration);
                    },
                    icon: const Icon(Icons.forward_10, size: 60, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        Positioned(
          bottom: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragUpdate: (details) {
              if (details.delta.dy < -10) {
                // Trigger das Sheet nur bei Hochwischen
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent, // Hintergrund des BottomSheet entfernen
                  builder: (context) => DraggableScrollableSheet(
                    initialChildSize: 0.4, // Startgröße
                    minChildSize: 0.4,     // Minimale Größe
                    maxChildSize: 0.8,     // Maximale Größe
                    builder: (context, scrollController) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.black54, // Sichtbare Farbe für Metadaten
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16.0),
                            topRight: Radius.circular(16.0),
                          ),
                        ),
                        child: ListView(
                          controller: scrollController,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                "Video-Metadaten",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ListTile(
                              leading: const Icon(Icons.date_range, color: Colors.white),
                              title: Text(
                                "Aufnahmedatum: ${widget.videoFile.lastModifiedSync().toString()}",
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            ListTile(
                              leading: const Icon(Icons.storage, color: Colors.white),
                              title: Text(
                                "Dateigröße: ${(widget.videoFile.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB",
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            ListTile(
                              leading: const Icon(Icons.location_on, color: Colors.white),
                              title: const Text(
                                "Standort: Nicht verfügbar",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 16.0), // Abstand vor der Karte
                            // Karte mit Route
                            Container(
                              height: 300, // Höhe der Karte
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(horizontal: 16.0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16.0),
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16.0),
                                child: GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: _loadedRoute.isNotEmpty
                                        ? _loadedRoute.first
                                        : const LatLng(0, 0), // Default-Koordinaten
                                    zoom: 14,
                                  ),
                                  polylines: {
                                    Polyline(
                                      polylineId: const PolylineId('route'),
                                      points: _loadedRoute,
                                      color: Colors.blue,
                                      width: 4,
                                    ),
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16.0), // Abstand nach der Karte
                          ],
                        ),
                      );
                    },
                  ),
                );
              }
            },
            child: Container(
              height: MediaQuery.of(context).size.height * 0.5, // Interaktiver Bereich nur unten
              width: MediaQuery.of(context).size.width,
              color: Colors.transparent,
            ),
          ),
        ),
      ],
    ),
  );
}
}