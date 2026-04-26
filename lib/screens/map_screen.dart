import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;

  final String googleApiKey = "AIzaSyAoO11fGnrFSG93iflX2_a7IIa-FkkfG7o";

  LatLng? _currentPosition;
  final Set<Marker> _markers = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocationAndGyms();
  }

  Future<void> _loadCurrentLocationAndGyms() async {
    try {
      final position = await _determinePosition();

      final userLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentPosition = userLatLng;
        _markers.add(
          Marker(
            markerId: const MarkerId("current_location"),
            position: userLatLng,
            infoWindow: const InfoWindow(title: "You are here"),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
          ),
        );
      });

      await _fetchNearbyGyms(userLatLng);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception("Location service is disabled. Please turn on GPS.");
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception("Location permission denied.");
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        "Location permission permanently denied. Enable it in app settings.",
      );
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _fetchNearbyGyms(LatLng location) async {
    final url = Uri.parse(
      "https://places.googleapis.com/v1/places:searchNearby",
    );

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": googleApiKey,
        "X-Goog-FieldMask":
        "places.displayName,places.formattedAddress,places.location,places.rating",
      },
      body: jsonEncode({
        "includedTypes": ["gym"],
        "maxResultCount": 10,
        "locationRestriction": {
          "circle": {
            "center": {
              "latitude": location.latitude,
              "longitude": location.longitude,
            },
            "radius": 3000.0
          }
        }
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to load nearby gyms: ${response.body}");
    }

    final data = jsonDecode(response.body);
    final places = data["places"] ?? [];

    for (var place in places) {
      final lat = place["location"]["latitude"];
      final lng = place["location"]["longitude"];
      final name = place["displayName"]["text"] ?? "Gym";
      final address = place["formattedAddress"] ?? "No address";
      final rating = place["rating"]?.toString() ?? "No rating";

      _markers.add(
        Marker(
          markerId: MarkerId(name),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: name,
            snippet: "$address\nRating: $rating",
          ),
        ),
      );
    }
  }

  void _goToMyLocation() {
    if (_currentPosition == null || _mapController == null) return;

    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(_currentPosition!, 15),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Nearby Gyms")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Nearby Gyms"),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _currentPosition!,
          zoom: 15,
        ),
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        markers: _markers,
        onMapCreated: (controller) {
          _mapController = controller;
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToMyLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}