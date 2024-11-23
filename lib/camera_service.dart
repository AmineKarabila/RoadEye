// Anpassung der Dateien um die Geschwindigkeit vom Gyrosensor zu berechnen und im Video anzuzeigen

import 'package:sensors_plus/sensors_plus.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as thumbnail;
import 'package:audio_session/audio_session.dart';

class CameraService {
  final CameraDescription cameraDescription;
  late CameraController _cameraController;
  bool get isInitialized => _cameraController.value.isInitialized;

  CameraService(this.cameraDescription);

  Future<void> initialize() async {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.speech());
    _cameraController = CameraController(cameraDescription, ResolutionPreset.high);
    await _cameraController.initialize();
  }

  Future<VideoCaptureResult?> captureVideo() async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String videoPath = '${appDir.path}/${DateTime.now().millisecondsSinceEpoch}.mp4';
      await _cameraController.startVideoRecording();

      await Future.delayed(const Duration(seconds: 5));
      XFile videoFile = await _cameraController.stopVideoRecording();

      File savedVideo = File(videoFile.path);
      await savedVideo.copy(videoPath);
      File? thumb = await _generateThumbnail(videoPath);

      return VideoCaptureResult(video: File(videoPath), thumbnail: thumb);
    } catch (e) {
      print("Fehler beim Aufnehmen des Videos: $e");
      return null;
    }
  }

  Future<File?> _generateThumbnail(String videoPath) async {
    final String? thumbPath = await thumbnail.VideoThumbnail.thumbnailFile(
      video: videoPath,
      thumbnailPath: (await getTemporaryDirectory()).path,
      imageFormat: thumbnail.ImageFormat.JPEG,
      quality: 75,
    );
    if (thumbPath != null) {
      return File(thumbPath);
    }
    return null;
  }

  CameraPreview getCameraPreview() => CameraPreview(_cameraController);

  void dispose() {
    _cameraController.dispose();
  }
}

class VideoCaptureResult {
  final File video;
  final File? thumbnail;

  VideoCaptureResult({required this.video, this.thumbnail});
}

class VideoPlayerScreen extends StatefulWidget {
  final File video;
  const VideoPlayerScreen({Key? key, required this.video}) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late StreamSubscription<GyroscopeEvent> _gyroscopeSubscription;
  double _currentSpeed = 0.0;
  double _previousSpeed = 0.0;
  DateTime? _lastUpdateTime;

  @override
  void initState() {
    super.initState();
    _startGyroscopeListener();
  }

  void _startGyroscopeListener() {
    _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      final DateTime currentTime = DateTime.now();
      if (_lastUpdateTime != null) {
        final double timeDiff = currentTime.difference(_lastUpdateTime!).inMilliseconds / 1000;

        // Integration des Gyrosensor-Werts zur Berechnung der Geschwindigkeit
        final double rotationalSpeed = event.x; // Gyroskop auf der x-Achse, kann an die Bewegungsrichtung angepasst werden
        _currentSpeed += rotationalSpeed * timeDiff;
      }
      _lastUpdateTime = currentTime;

      setState(() {
        _previousSpeed = _currentSpeed;
      });
    });
  }

  @override
  void dispose() {
    _gyroscopeSubscription.cancel();
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
            child: Text(
              "Geschwindigkeit: ${_currentSpeed.toStringAsFixed(2)} rad/s",
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Füge hier die Videoanzeige hinzu, wenn gewünscht
        ],
      ),
    );
  }
}
