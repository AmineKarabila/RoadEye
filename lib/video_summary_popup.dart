import 'package:flutter/material.dart';
import 'dart:io';

class VideoSummaryPopup extends StatelessWidget {
  final File thumbnail;
  final File mapImage;
  final double avgSpeed;
  final double maxSpeed;
  final double minSpeed;
  final VoidCallback onClose;
  final VoidCallback onPlayVideo;

  const VideoSummaryPopup({
    Key? key,
    required this.thumbnail,
    required this.mapImage,
    required this.avgSpeed,
    required this.maxSpeed,
    required this.minSpeed,
    required this.onClose,
    required this.onPlayVideo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Fahrtübersicht",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Image.file(
              thumbnail,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 10),
            Image.file(
              mapImage,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 10),
            Text("Durchschnittsgeschwindigkeit: ${avgSpeed.toStringAsFixed(2)} km/h"),
            Text("Höchstgeschwindigkeit: ${maxSpeed.toStringAsFixed(2)} km/h"),
            Text("Niedrigstgeschwindigkeit: ${minSpeed.toStringAsFixed(2)} km/h"),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: onClose,
                  child: const Text("Schließen"),
                ),
                ElevatedButton(
                  onPressed: onPlayVideo,
                  child: const Text("Video abspielen"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

