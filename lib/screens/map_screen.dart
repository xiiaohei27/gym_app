import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatelessWidget {
  final LatLng gym = LatLng(3.1390, 101.6869);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Gym Locator")),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: gym,
          zoom: 14,
        ),
        markers: {
          Marker(markerId: MarkerId("gym"), position: gym)
        },
      ),
    );
  }
}