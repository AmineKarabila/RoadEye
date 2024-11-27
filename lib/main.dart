// main.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'camera_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'videoplayer.dart';
import 'video_summary_popup.dart';
import 'video_details_screen.dart';
import 'map_generator.dart';
import "render_image.dart";


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
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
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
  StreamSubscription<Position>? _positionSubscription;
  List<Map<String, dynamic>> _metadata = [];

  @override
  void initState() {
    super.initState();
    _cameraService = CameraService(widget.cameras.first);
    _initializeCamera(); // Kamera initialisieren
    _startClock(); // Startet die Uhr zur Anzeige der aktuellen Uhrzeit
    _startTrackingSpeed(); // Startet die Geschwindigkeitserfassung über GPS
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
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0, // Erfassung auch bei minimalster Bewegung
        ),
      ).listen((Position position) {
        setState(() {
          // Geschwindigkeit in m/s direkt aus GPS-Daten
          double newSpeed = position.speed;

          // Erhöhung der Empfindlichkeit: Geschwindigkeit wird in 0.1 km/h Schritten erhöht/angezeigt
          _currentSpeed = newSpeed < 0 ? 0.0 : double.parse((newSpeed * 3.6).toStringAsFixed(1)) / 3.6; // Umwandlung zurück in m/s mit 0.1 km/h Schritten
        });
      });
    } else {
      setState(() {
        _currentSpeed = 0.0; // Keine Berechtigung -> Geschwindigkeit auf 0 setzen
      });
    }
  }
Future<void> _captureVideo() async {
  if (_isCameraInitialized && !_isRecording) {
    setState(() {
      _isRecording = true;
      _metadata.clear(); // Clear metadata before recording
    });

    await _cameraService.startVideoRecording();
  } else if (_isRecording) {
    final result = await _cameraService.stopVideoRecording();

    setState(() async {
      if (result != null) {
        _recordedVideos.add(result.video);
        if (result.thumbnail != null) {
          _thumbnails.add(result.thumbnail!);
        }
        await _saveMetadata(result.video.path);

        // Generate the map image
        File? mapImage;
        try {
          mapImage = await generateMap(_metadata);
        } catch (e) {
          print("Fehler bei der Karten-Generierung: $e");
        }

        // Fallback auf Platzhalterbild
        mapImage ??= null; // Kein Platzhalter im Code, Widget zeigt das Asset


        // Berechne Geschwindigkeitsstatistiken
        double calculatedAvgSpeed = _metadata.map((data) => data['speed_kmph']).reduce((a, b) => a + b) / _metadata.length;
        double calculatedMaxSpeed = _metadata.map((data) => data['speed_kmph']).reduce((a, b) => a > b ? a : b);
        double calculatedMinSpeed = _metadata.map((data) => data['speed_kmph']).reduce((a, b) => a < b ? a : b);

        // Zeige das Pop-up mit den Ergebnissen
        showDialog(
          context: context,
          builder: (context) => VideoSummaryPopup(
            thumbnail: result.thumbnail!,
            mapImage: mapImage,
            avgSpeed: calculatedAvgSpeed,
            maxSpeed: calculatedMaxSpeed,
            minSpeed: calculatedMinSpeed,
            onClose: () => Navigator.of(context).pop(),
            onPlayVideo: () {
              Navigator.of(context).pop();
              _playVideo(result.video);
            },
          ),
        );
      }
      _isRecording = false;
    });
  }
}




  Future<void> _saveMetadata(String videoPath) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final metadataPath = '${directory.path}/${videoPath.split('/').last}_metadata.json';
      final File metadataFile = File(metadataPath);
      await metadataFile.writeAsString(jsonEncode(_metadata));
    } catch (e) {
      print('Fehler beim Speichern der Metadaten: $e');
    }
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
          color: Colors.black87,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: _recordedVideos.isEmpty
            ? Center(
                child: Text(
                  "Noch keine Videos vorhanden",
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade300),
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
  final directory = await getApplicationDocumentsDirectory();
  final metadataPath = '${directory.path}/${videoFile.path.split('/').last}_metadata.json';
  File metadataFile = File(metadataPath);
  List<Map<String, dynamic>> metadata = [];
  if (await metadataFile.exists()) {
    final String content = await metadataFile.readAsString();
    metadata = List<Map<String, dynamic>>.from(jsonDecode(content));
  }

  // Lade die Karte, falls sie existiert
  final mapPath = '${directory.path}/${videoFile.path.split('/').last}_map.png';
  File? mapImage = File(mapPath);
  if (!await mapImage.exists()) {
    print("Karte nicht gefunden. Generiere neue Karte...");
    try {
      mapImage = await generateMap(metadata);
    } catch (e) {
      print("Fehler bei der Karten-Generierung: $e");
      mapImage = File('assets/placeholder_map.png'); // Platzhalterbild aus Assets
    }
  }

  // Fallback auf Platzhalterbild
  mapImage ??= null; // Kein Platzhalter im Code, Widget zeigt das Asset


  double avgSpeed = metadata.map((data) => data['speed_kmph']).reduce((a, b) => a + b) / metadata.length;
  double maxSpeed = metadata.map((data) => data['speed_kmph']).reduce((a, b) => a > b ? a : b);
  double minSpeed = metadata.map((data) => data['speed_kmph']).reduce((a, b) => a < b ? a : b);

  Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (context) => VideoSummaryPopupWidget(
    thumbnail: result.thumbnail!,
    mapImage: mapImage,
    avgSpeed: calculatedAvgSpeed,
    maxSpeed: calculatedMaxSpeed,
    minSpeed: calculatedMinSpeed,
    onClose: () => Navigator.of(context).pop(),
    onPlayVideo: () {
      Navigator.of(context).pop();
      _playVideo(result.video);
  },
),
  ));
}



  @override
  void dispose() {
    _cameraService.dispose();
    _positionSubscription?.cancel(); // Beende das GPS-Tracking
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("RoadEye"),
      ),
      body: SafeArea(
        child: _isCameraInitialized
            ? Stack(
                children: [
                  Positioned.fill(
                    child: _cameraService.getCameraPreview(),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.black.withOpacity(0.7),
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
              color: Colors.black87,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
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
                      Icon(Icons.video_library, size: 28, color: Colors.grey.shade300),
                      const SizedBox(height: 5),
                      Text(
                        "Galerie",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
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
                      Icon(Icons.settings, size: 28, color: Colors.grey.shade300),
                      const SizedBox(height: 5),
                      Text(
                        "Einstellungen",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
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
