import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _apiKey = "AIzaSyAoO11fGnrFSG93iflX2_a7IIa-FkkfG7o";
  static const _placesApiKey = "AIzaSyBibM8-2v4F-8oQM2TRZEDAeDINpvRNPbE";
  static const _searchRadius = 3000.0;
  static const _zoomLevel = 15.0;

  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  Set<Marker> _markers = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final pos = await _getPosition();
      final latLng = LatLng(pos.latitude, pos.longitude);
      final gyms = await _fetchNearbyGyms(latLng);

      // Single setState for everything
      setState(() {
        _currentPosition = latLng;
        _markers = {
          Marker(
            markerId: const MarkerId("me"),
            position: latLng,
            infoWindow: const InfoWindow(title: "You are here"),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ),
          ...gyms,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<Position> _getPosition() async {
    // Request permission first
    final permissionStatus = await Permission.location.request();

    if (permissionStatus.isDenied || permissionStatus.isPermanentlyDenied) {
      if (permissionStatus.isPermanentlyDenied) {
        await openAppSettings(); // opens app settings
      }
      throw Exception("Location permission denied.");
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception("GPS is disabled. Please turn it on.");
    }

    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<Set<Marker>> _fetchNearbyGyms(LatLng loc) async {
    final res = await http.post(
      Uri.parse("https://places.googleapis.com/v1/places:searchNearby"),
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": _placesApiKey,
        "X-Goog-FieldMask": "places.displayName,places.formattedAddress,places.location,places.rating",
      },
      body: jsonEncode({
        "includedTypes": ["gym"],
        "maxResultCount": 10,
        "locationRestriction": {
          "circle": {
            "center": {"latitude": loc.latitude, "longitude": loc.longitude},
            "radius": _searchRadius,
          },
        },
      }),
    );

    if (res.statusCode != 200) throw Exception("Failed to fetch gyms: ${res.body}");

    final places = (jsonDecode(res.body)["places"] as List?) ?? [];

    return places.map((p) {
      final name = p["displayName"]["text"] ?? "Gym";
      return Marker(
        markerId: MarkerId(name),
        position: LatLng(p["location"]["latitude"], p["location"]["longitude"]),
        infoWindow: InfoWindow(
          title: name,
          snippet: "${p["formattedAddress"] ?? "No address"} · ★ ${p["rating"] ?? "N/A"}",
        ),
      );
    }).toSet();
  }

  void _goToMyLocation() {
    if (_currentPosition == null || _mapController == null) return;
    _mapController!.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition!, _zoomLevel));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Nearby Gyms")),
        body: Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_errorMessage!, textAlign: TextAlign.center))),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Nearby Gyms")),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: _currentPosition!, zoom: _zoomLevel),
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        markers: _markers,
        onMapCreated: (c) => _mapController = c,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToMyLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}