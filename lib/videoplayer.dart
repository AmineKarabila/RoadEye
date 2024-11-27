
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';

import 'package:video_player/video_player.dart';
import 'video_details_screen.dart';

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
      actions: [
        IconButton(
          icon: const Icon(Icons.info),
          onPressed: () {
            // Berechnung der Geschwindigkeitsstatistiken
            double avgSpeed = widget.metadata.map((data) => data['speed_kmph']).reduce((a, b) => a + b) / widget.metadata.length;
            double maxSpeed = widget.metadata.map((data) => data['speed_kmph']).reduce((a, b) => a > b ? a : b);
            double minSpeed = widget.metadata.map((data) => data['speed_kmph']).reduce((a, b) => a < b ? a : b);

            // Öffne den neuen Bildschirm
            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => VideoDetailsScreen(
                avgSpeed: avgSpeed,
                maxSpeed: maxSpeed,
                minSpeed: minSpeed,
              ),
            ));
          },
        ),
      ],
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
