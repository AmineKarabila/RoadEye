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

  Future<void> startVideoRecording() async {
    try {
      await _cameraController.startVideoRecording();
    } catch (e) {
      print("Fehler beim Starten der Videoaufnahme: $e");
    }
  }

  Future<VideoCaptureResult?> stopVideoRecording() async {
    try {
      XFile videoFile = await _cameraController.stopVideoRecording();
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String videoPath = '${appDir.path}/${DateTime.now().millisecondsSinceEpoch}.mp4';

      File savedVideo = File(videoFile.path);
      await savedVideo.copy(videoPath);
      File? thumb = await _generateThumbnail(videoPath);

      return VideoCaptureResult(video: File(videoPath), thumbnail: thumb);
    } catch (e) {
      print("Fehler beim Stoppen der Videoaufnahme: $e");
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
