import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';

class CameraService {
  final CameraDescription cameraDescription;
  late CameraController _cameraController;
  


  CameraService(this.cameraDescription);

  Future<void> initialize() async {
    _cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.high,
    );
    await _cameraController.initialize();
  }
  CameraController get controller => _cameraController;

  Widget getCameraPreview() {
    return CameraPreview(_cameraController);
  }

  Future<void> dispose() async {
    await _cameraController.dispose();
  }

  Future<void> startVideoRecording() async {
    if (_cameraController.value.isInitialized) {
      await _cameraController.startVideoRecording();
    }
  }

  Future<CameraRecordingResult?> stopVideoRecording() async {
    if (_cameraController.value.isRecordingVideo) {
      final result = await _cameraController.stopVideoRecording();
      return CameraRecordingResult(video: File(result.path));
    }
    return null;
  }

  Future<void> setFlashMode(FlashMode mode) async {
    if (_cameraController.value.isInitialized) {
      await _cameraController.setFlashMode(mode);
    }
  }
}

class CameraRecordingResult {
  final File video;

  CameraRecordingResult({required this.video});
}
