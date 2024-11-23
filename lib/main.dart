// main.dart

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'camera_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MyHomePage(cameras: cameras),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const MyHomePage({super.key, required this.cameras});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late CameraService _cameraService;
  bool _isCameraInitialized = false;
  List<File> _recordedVideos = [];
  List<File> _thumbnails = [];
  bool _isRecording = false;
  String _currentTime = "";
  double _currentSpeed = 0.0; // Geschwindigkeit in m/s
  late StreamSubscription<AccelerometerEvent> _accelerometerSubscription;
  double _accelerationX = 0.0;
  double _accelerationY = 0.0;
  double _accelerationZ = 0.0;
  List<Map<String, dynamic>> _metadata = [];

  @override
  void initState() {
    super.initState();
    _cameraService = CameraService(widget.cameras.first);
    _initializeCamera(); // Kamera initialisieren
    _startClock(); // Startet die Uhr zur Anzeige der aktuellen Uhrzeit
    _startAccelerometer(); // Startet den Beschleunigungssensor
  }

  Future<void> _initializeCamera() async {
    await _cameraService.initialize();
    setState(() {
      _isCameraInitialized = true;
    });
  }

  void _startClock() {
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _currentTime = DateFormat('HH:mm:ss.SSS').format(DateTime.now());
        _currentSpeed = _calculateSpeedFromAcceleration(); // Geschwindigkeit basierend auf Beschleunigung berechnen
      });
      // Während der Aufnahme die Uhrzeit und Geschwindigkeit als Metadatum speichern
      if (_isRecording) {
        _metadata.add({
          'time': _currentTime,
          'speed_mps': _currentSpeed,
          'speed_kmph': double.parse((_currentSpeed * 3.6).toStringAsFixed(2)),
        });
      }
    });
  }

  void _startAccelerometer() {
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      setState(() {
        _accelerationX = event.x;
        _accelerationY = event.y;
        _accelerationZ = event.z;
      });
    });
  }

  double _calculateSpeedFromAcceleration() {
    // Berechnung der Geschwindigkeit basierend auf der Beschleunigung
    double accelerationMagnitude = sqrt(
      (_accelerationX * _accelerationX) +
      (_accelerationY * _accelerationY) +
      (_accelerationZ * _accelerationZ),
    );

    // Kleinen Schwellenwert definieren, um Rauschen zu ignorieren
    const double threshold = 1.0; // Einheit in m/s^2

    // Wenn die Beschleunigung geringer als der Schwellenwert ist, Dämpfung anwenden
    if (accelerationMagnitude < threshold) {
      _currentSpeed *= 0.95; // Geschwindigkeit allmählich dämpfen
    } else {
      // Geschwindigkeit berechnen: Geschwindigkeit = Beschleunigung * Zeit
      // Da wir alle 0.1 Sekunden abtasten, ist deltaTime = 0.1
      _currentSpeed += (accelerationMagnitude * 0.1);
    }

    if (_currentSpeed < 0) {
      _currentSpeed = 0; // Geschwindigkeit kann nicht negativ sein
    }
    return _currentSpeed;
  }

  Future<void> _captureVideo() async {
    if (_isCameraInitialized && !_isRecording) {
      setState(() {
        _isRecording = true;
        _metadata.clear(); // Vor der Aufnahme Metadatenliste leeren
      });

      final result = await _cameraService.captureVideo();

      setState(() {
        if (result != null) {
          _recordedVideos.add(result.video);
          if (result.thumbnail != null) {
            _thumbnails.add(result.thumbnail!);
          }
          _saveMetadata(result.video.path); // Metadaten nach der Aufnahme speichern
        }
        _isRecording = false;
      });
    }
  }

  Future<void> _saveMetadata(String videoPath) async {
    final metadataPath = '${videoPath}_metadata.json';
    final File metadataFile = File(metadataPath);
    await metadataFile.writeAsString(jsonEncode(_metadata));
  }

  void _showGallery() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => Container(
        height: 400,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: _recordedVideos.isEmpty
            ? Center(
                child: Text(
                  "Noch keine Videos vorhanden",
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade800),
                ),
              )
            : GridView.builder(
                itemCount: _recordedVideos.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => _playVideo(_recordedVideos[index]),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _thumbnails.length > index
                              ? Image.file(
                                  _thumbnails[index],
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: Colors.black12,
                                ),
                        ),
                        const Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _playVideo(File videoFile) async {
    // Lade die Metadaten
    final metadataPath = '${videoFile.path}_metadata.json';
    File metadataFile = File(metadataPath);
    List<Map<String, dynamic>> metadata = [];
    if (await metadataFile.exists()) {
      final String content = await metadataFile.readAsString();
      metadata = List<Map<String, dynamic>>.from(jsonDecode(content));
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(videoFile: videoFile, metadata: metadata),
      ),
    );
  }

  @override
  void dispose() {
    _cameraService.dispose();
    _accelerometerSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("Flutter Camera Demo"),
      ),
      body: SafeArea(
        child: _isCameraInitialized
            ? Stack(
                children: [
                  // Kamera-Vorschau anzeigen
                  Positioned.fill(
                    child: _cameraService.getCameraPreview(),
                  ),
                  // Aktuelle Uhrzeit anzeigen
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.black.withOpacity(0.5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Zeit: $_currentTime",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Geschwindigkeit: ${_currentSpeed.toStringAsFixed(2)} m/s (${(_currentSpeed * 3.6).toStringAsFixed(2)} km/h)",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : const Center(child: CircularProgressIndicator()), // Ladeindikator
      ),
      bottomNavigationBar: Stack(
        clipBehavior: Clip.none,
        children: [
          // Hintergrund der BottomBar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 5,
                  blurRadius: 10,
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            height: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Galerie Button
                GestureDetector(
                  onTap: _showGallery,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.video_library, size: 28, color: Colors.grey.shade800),
                      const SizedBox(height: 5),
                      Text(
                        "Galerie",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 60), // Leerraum für den mittigen Button
                GestureDetector(
                  onTap: () {
                    print("Einstellungen Button gedrückt");
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.settings, size: 28, color: Colors.grey.shade800),
                      const SizedBox(height: 5),
                      Text(
                        "Einstellungen",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -30,
            left: MediaQuery.of(context).size.width / 2 - 40,
            child: GestureDetector(
              onTap: _captureVideo,
              child: Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: _isRecording ? Colors.red : Colors.deepPurple,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.4),
                      spreadRadius: 5,
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(Icons.videocam, color: Colors.white, size: 40),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// VideoPlayerScreen Widget zum Abspielen eines Videos
class VideoPlayerScreen extends StatefulWidget {
  final File videoFile;
  final List<Map<String, dynamic>> metadata;
  const VideoPlayerScreen({super.key, required this.videoFile, required this.metadata});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  late Timer _metadataTimer;
  String _currentTime = "";
  String _currentSpeed = "";
  int _metadataIndex = 0;

  @override
  void initState() {
    super.initState();
    _videoPlayerController = VideoPlayerController.file(widget.videoFile)
      ..initialize().then((_) {
        setState(() {});
        _videoPlayerController.play();
        _startMetadataTimer();
      });
  }

  void _startMetadataTimer() {
    _metadataTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_metadataIndex < widget.metadata.length) {
        setState(() {
          _currentTime = widget.metadata[_metadataIndex]['time'];
          _currentSpeed = "${widget.metadata[_metadataIndex]['speed_mps'].toStringAsFixed(2)} m/s (${widget.metadata[_metadataIndex]['speed_kmph'].toStringAsFixed(2)} km/h)";
          _metadataIndex++;
        });
      } else {
        _metadataTimer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _metadataTimer.cancel();
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
            child: _videoPlayerController.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _videoPlayerController.value.aspectRatio,
                    child: VideoPlayer(_videoPlayerController),
                  )
                : const CircularProgressIndicator(),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black.withOpacity(0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Zeit: $_currentTime",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Geschwindigkeit: $_currentSpeed",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}



/*
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS Geschwindigkeit',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  double _speed = 0.0; // Geschwindigkeit in m/s
  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _startTrackingSpeed();
  }

  void _startTrackingSpeed() async {
    // Prüfe und fordere Standortberechtigungen an
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      // Abonniere die Positionsänderungen
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // Aktualisierung nach mindestens 5 Metern Bewegung
        ),
      ).listen((Position position) {
        setState(() {
          // Geschwindigkeit in m/s direkt aus GPS-Daten
          _speed = position.speed; // Geschwindigkeit in m/s
        });
      });
    } else {
      setState(() {
        _speed = 0.0; // Keine Berechtigung -> Geschwindigkeit auf 0 setzen
      });
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("GPS Geschwindigkeit"),
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Aktuelle Geschwindigkeit:",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Text(
                "${_speed.toStringAsFixed(2)} m/s",
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                "${(_speed * 3.6).toStringAsFixed(2)} km/h",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


*/
