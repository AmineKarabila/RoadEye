import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'render_image.dart';
import 'dart:io';


Future<File> generateMap(List<Map<String, dynamic>> coordinates) async {
  // Convert coordinates to LatLng
  List<LatLng> polylineCoordinates = coordinates
      .map((coord) => LatLng(coord['latitude'], coord['longitude']))
      .toList();

  // Create the map widget
  final mapWidget = GoogleMap(
    initialCameraPosition: CameraPosition(
      target: polylineCoordinates.first,
      zoom: 14,
    ),
    polylines: {
      Polyline(
        polylineId: PolylineId('route'),
        points: polylineCoordinates,
        color: Colors.blue,
        width: 5,
      ),
    },
  );

  // Render the map widget as an image
  final mapImage = await renderMapAsImage(mapWidget);
  return mapImage;
}

