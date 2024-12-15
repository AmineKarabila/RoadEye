import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'camera_service.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraService _cameraService;
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;
  bool _isFrontCamera = false;
  bool _isRecording = false;
  List<File> _recordedVideos = [];

  @override
  void initState() {
    super.initState();
    _cameraService = CameraService(widget.cameras.first);
    _initializeCamera();
  }

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
    if (_isRecording) {
      final result = await _cameraService.stopVideoRecording();
      if (result != null) {
        setState(() {
          _recordedVideos.add(result.video);
        });
      }
    } else {
      await _cameraService.startVideoRecording();
    }
    setState(() {
      _isRecording = !_isRecording;
    });
  }

  void _showGallery() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(8.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8.0,
            mainAxisSpacing: 8.0,
          ),
          itemCount: _recordedVideos.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoPlayerScreen(videoFile: _recordedVideos[index]),
                  ),
                );
              },
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.file(
                      _recordedVideos[index],
                      fit: BoxFit.cover,
                    ),
                  ),
                  const Align(
                    alignment: Alignment.bottomCenter,
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 50,
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

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
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
                        ),
                        const SizedBox(height: 20),
                        IconButton(
                          onPressed: _toggleCameraView,
                          icon: Icon(
                            _isFrontCamera ? Icons.camera_front : Icons.camera_rear,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        IconButton(
                          onPressed: _showGallery,
                          icon: const Icon(
                            Icons.photo_library,
                            color: Colors.white,
                          ),
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
                ],
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final File videoFile;

  const VideoPlayerScreen({super.key, required this.videoFile});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.videoFile)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
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
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
