import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'camera_service.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'speed_service.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'video_player_screen.dart';
import 'main.dart';
import 'file_storage_util.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as thumbnail;


class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraScreen({super.key, required this.cameras});
    
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late SpeedService _speedService;  // Speedcalc
  double _currentSpeed = 0.0;       // Speedcalc


  List<LatLng> _routeCoordinates = [];
  late GoogleMapController _mapController;

  late CameraService _cameraService;
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;
  bool _isFrontCamera = false;
  bool _isRecording = false;
  List<File> _recordedVideos = [];

//------------    SPEED -----------------

  @override
  void initState() {
    super.initState();
  
    _loadPersistentData();
    _cameraService = CameraService(widget.cameras.first);
    _initializeCamera();
    _speedService = SpeedService();
    _speedService.speedStream.listen((speed) {
      setState(() {
        _currentSpeed = speed;
      });
    });
  }

  Future<List<File>> loadVideos() async {
    // Hole den persistenten Speicherort
    final persistentDir = await FileStorageUtil.getPersistentDirectory();
    
    // Durchsuche den Ordner nach .mp4-Dateien
    return persistentDir
        .listSync()
        .where((file) => file.path.endsWith('.mp4'))
        .map((file) => File(file.path))
        .toList();
  }

  void _loadPersistentData() async {
    final persistentDir = await FileStorageUtil.getPersistentDirectory();
    final videoFiles = persistentDir
        .listSync()
        .where((file) => file.path.endsWith('.mp4'))
        .map((file) => File(file.path))
        .toList();

    setState(() {
      _recordedVideos.addAll(videoFiles);
    });
  }
  
 

  @override
  void dispose() {
    _cameraService.dispose();
    _speedService.dispose();
    _cameraService.dispose();
    super.dispose();
  }

  final FlutterFFmpeg _flutterFFmpeg = FlutterFFmpeg();
  late String _textFilePath;
  List<String> _speedOverlayData = [];

  void _initializeTextFile() async {
    final directory = await getApplicationDocumentsDirectory();
    _textFilePath = '${directory.path}/speed_overlay.txt';
    File(_textFilePath).writeAsStringSync(''); // Leere Datei erstellen
  }

  void _appendSpeedToOverlay() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _speedOverlayData.add('$timestamp|${_currentSpeed.toStringAsFixed(1)} km/h');
    File(_textFilePath).writeAsStringSync(
      _speedOverlayData.join('\n'),
      mode: FileMode.writeOnlyAppend,
    );
  }

  void _processVideo(File videoFile) async {
  final directory = await getApplicationDocumentsDirectory();
  final outputFilePath = '${directory.path}/output_video.mp4';

  final ffmpegCommand = [
    '-y', // Erlaubt das Überschreiben bestehender Dateien
    '-i', videoFile.path,
    '-vf',
    'drawtext=textfile=$_textFilePath:fontcolor=white:fontsize=24:x=10:y=10',
    '-c:a', 'copy',
    outputFilePath,
  ];


  await _flutterFFmpeg.executeWithArguments(ffmpegCommand).then((rc) {
    if (rc == 0) {
      print("Video erfolgreich verarbeitet und gespeichert: $outputFilePath");
    } else {
      print("Fehler bei der Videoverarbeitung: RC=$rc");
    }
  });

}

  


//------------    MAPS -----------------

 Future<void> _saveRoute(List<LatLng> route, String videoFileName) async {
    final persistentDir = await FileStorageUtil.getPersistentDirectory();
    final routePath = '${persistentDir.path}/${videoFileName}_route.json';

    final routeData = route
        .map((coord) => {'latitude': coord.latitude, 'longitude': coord.longitude})
        .toList();

    final file = File(routePath);
    await file.writeAsString(jsonEncode(routeData));
    print('Route gespeichert: $routePath');
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  LatLngBounds _calculateBounds(List<LatLng> coordinates) {
    double south = coordinates.first.latitude;
    double north = coordinates.first.latitude;
    double west = coordinates.first.longitude;
    double east = coordinates.first.longitude;

    for (var coord in coordinates) {
      if (coord.latitude < south) south = coord.latitude;
      if (coord.latitude > north) north = coord.latitude;
      if (coord.longitude < west) west = coord.longitude;
      if (coord.longitude > east) east = coord.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }


  void _startTracking() async {
    final hasPermission = await Geolocator.checkPermission();
    if (hasPermission == LocationPermission.denied ||
        hasPermission == LocationPermission.deniedForever) {
      final permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Standortberechtigung abgelehnt")),
        );
        return;
      }
    }
    // Start Tracking
    Geolocator.getPositionStream().listen((Position position) {
      setState(() {
        _routeCoordinates.add(LatLng(position.latitude, position.longitude));
      });
    });
  }

  void _stopTracking() {
    _showRoutePopup();
  }

void _showRoutePopup() {
  if (_routeCoordinates.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Keine Route aufgezeichnet")),
    );
    return;
  }

  final LatLng startPoint = _routeCoordinates.first;
  final LatLng endPoint = _routeCoordinates.last;

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
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                        // Kamera auf die gesamte Route einstellen
                        _mapController.animateCamera(
                          CameraUpdate.newLatLngBounds(
                            _calculateBounds(_routeCoordinates),
                            50, // Padding
                          ),
                        );
                      },
                      initialCameraPosition: CameraPosition(
                        target: startPoint,
                        zoom: 14,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId('start'),
                          position: startPoint,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueGreen), // Grüne Flagge für Start
                          infoWindow: const InfoWindow(title: 'Startpunkt'),
                        ),
                        Marker(
                          markerId: const MarkerId('end'),
                          position: endPoint,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueRed), // Rote Flagge für Ziel
                          infoWindow: const InfoWindow(title: 'Zielpunkt'),
                        ),
                      },
                      polylines: {
                        Polyline(
                          polylineId: const PolylineId('route'),
                          points: _routeCoordinates,
                          color: Colors.blue,
                          width: 4,
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


//---------------------------------------




  Future<void> _initializeCamera() async {
    await _cameraService.initialize();
    setState(() {
      _isCameraInitialized = true;
    });
  }

  void _toggleFlash() async {
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
    await _cameraService.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
  }

  void _toggleCameraView() async {
    final newCamera = _isFrontCamera
        ? widget.cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back)
        : widget.cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
            orElse: () => widget.cameras.first,
          );

    setState(() {
      _isFrontCamera = !_isFrontCamera;
      _cameraService = CameraService(newCamera);
    });
    await _initializeCamera();
  }

void _startStopRecording() async {
  try {
    if (_isRecording) {
      // Stop Recording
      _stopTracking();
      final result = await _cameraService.stopVideoRecording();
      if (result != null) {
        // Video in den persistenten Speicher verschieben
        final persistentDir = await FileStorageUtil.getPersistentDirectory();
        final savedVideo = await result.video.copy(
          '${persistentDir.path}/${result.video.path.split('/').last}',
        );

        // Route speichern
        await _saveRoute(_routeCoordinates, savedVideo.path.split('/').last);

        setState(() {
          _recordedVideos.add(savedVideo); // Persistent gespeichertes Video verwenden
        });

        // Prozessierung des Videos (falls weiterhin benötigt)
        _processVideo(savedVideo);
      }
    } else {
      // Start Recording
      if (_cameraService.controller.value.isRecordingVideo) {
        print("Videoaufnahme läuft bereits");
        return;
      }
      _speedOverlayData.clear();
      _initializeTextFile();

      await _cameraService.startVideoRecording(); // Nur einmal aufrufen!
      Timer.periodic(Duration(milliseconds: 500), (timer) {
        if (!_isRecording) timer.cancel();
        _appendSpeedToOverlay();
      });
      _startTracking();
    }

    // Status ändern
    setState(() {
      _isRecording = !_isRecording;
    });
  } catch (e) {
    print("Fehler bei der Videoaufnahme: $e");
  }
}

Future<File?> _generateThumbnail(String videoPath) async {
  // Initialisiere den VideoPlayerController, um die Länge zu ermitteln
  final controller = VideoPlayerController.file(File(videoPath));
  await controller.initialize();

  // Berechne die Mitte des Videos in Millisekunden
  final int middleTime = (controller.value.duration.inMilliseconds / 2).round();

  // Generiere das Thumbnail aus der Mitte des Videos
  final thumbnailPath = await thumbnail.VideoThumbnail.thumbnailFile(
    video: videoPath,
    thumbnailPath: (await getTemporaryDirectory()).path,
    imageFormat: thumbnail.ImageFormat.JPEG,
    timeMs: middleTime, // Zeit in der Mitte des Videos
    maxHeight: 200, // Höhe des Thumbnails
    quality: 75,    // Qualität des Thumbnails
  );

  // Entsorge den Controller
  controller.dispose();

  if (thumbnailPath != null) {
    return File(thumbnailPath);
  }
  return null;
}



void _showGallery() {
  showModalBottomSheet(
    context: context,
    builder: (context) => Container(
      padding: const EdgeInsets.all(8.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // Zwei Elemente pro Reihe
          crossAxisSpacing: 8.0, // Horizontaler Abstand
          mainAxisSpacing: 40.0, // Mehr vertikaler Abstand zwischen den Reihen
        ),
        itemCount: _recordedVideos.length,
        itemBuilder: (context, index) {
          final videoFile = _recordedVideos[index];
          final date = videoFile.lastModifiedSync();

          return FutureBuilder<File?>(
            future: _generateThumbnail(videoFile.path),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              } else if (snapshot.hasError || snapshot.data == null) {
                return const Center(
                  child: Icon(Icons.error, color: Colors.red),
                );
              }

              final thumbnail = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              VideoPlayerScreen(videoFile: videoFile),
                        ),
                      );
                    },
                    child: AspectRatio(
                      aspectRatio: 1, // Quadratische Anzeige
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.0), // Runde Ecken
                              child: Image.file(
                                thumbnail,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const Center(
                            child: Icon(
                              Icons.play_circle_fill,
                              color: Colors.white,
                              size: 50,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4.0), // Abstand zum Text
                  Text(
                    '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}', // Format: DD.MM.YYYY HH:mm
                    style: const TextStyle(
                      fontSize: 12.0,
                      color: Colors.white70,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isCameraInitialized
            ? Stack(
                children: [
                  Positioned.fill(
                    child: _cameraService.getCameraPreview(),
                  ),
                  Positioned(
                    right: 10,
                    top: 50,
                    child: Column(
                      children: [
                        IconButton(
                          onPressed: _toggleFlash,
                          icon: Icon(
                            _isFlashOn ? Icons.flash_on : Icons.flash_off,
                            color: Colors.white,
                          ),
                          iconSize: 30.0,
                        ),
                        const SizedBox(height: 20),
                        IconButton(
                          onPressed: _toggleCameraView,
                          icon: Icon(
                            _isFrontCamera ? Icons.camera_front : Icons.camera_rear,
                            color: Colors.white,
                          ),
                          iconSize: 30.0,
                        ),
                        const SizedBox(height: 20),
                        IconButton(
                          onPressed: _showGallery,
                          icon: const Icon(
                            Icons.photo_library,
                            color: Colors.white,
                          ),
                          iconSize: 30.0,
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: GestureDetector(
                      onTap: _startStopRecording,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording ? Colors.red : Colors.white,
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.videocam,
                          color: _isRecording ? Colors.white : Colors.red,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        "${_currentSpeed.toStringAsFixed(1)} km/h",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
