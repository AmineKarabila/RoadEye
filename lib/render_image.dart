import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui; // Import für ImageByteFormat
import 'package:path_provider/path_provider.dart';

Future<File> renderMapAsImage(Widget mapWidget) async {
  // Create a global key to identify the widget
  final GlobalKey repaintBoundaryKey = GlobalKey();

  // Wrap the map widget in a RepaintBoundary
  final boundaryWidget = RepaintBoundary(
    key: repaintBoundaryKey,
    child: SizedBox(
      width: 600, // Customize the width
      height: 400, // Customize the height
      child: mapWidget,
    ),
  );

  // Render the widget to an image
  final renderObject = repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (renderObject == null) {
    throw Exception("Failed to find render object for map");
  }

  final image = await renderObject.toImage(pixelRatio: 2.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

  if (byteData == null) {
    throw Exception("Failed to render map to image");
  }

  final buffer = byteData.buffer.asUint8List();

  // Save the image to a file
  final directory = await getApplicationDocumentsDirectory();
  final filePath = '${directory.path}/map_image_${DateTime.now().millisecondsSinceEpoch}.png';
  final file = File(filePath);
  await file.writeAsBytes(buffer);

  return file;
}
