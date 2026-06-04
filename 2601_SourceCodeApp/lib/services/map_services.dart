import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MapServices {
  /// Ensures location services are enabled and permissions are granted
  /// Plays a crucial role to avoid duplicated permission handling logic.
  /// Throws an exception if services are disabled or permissions are denied permanently.
  static Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  /// Fetches the route polyline between two LatLng points using Google Directions API
  static Future<String?> fetchRoutePolyline(
    LatLng origin,
    LatLng destination,
    String apiKey,
  ) async {
    final url =
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          return data['routes'][0]['overview_polyline']['points'] as String?;
        } else {
          debugPrint('Directions API Error: ${data['status']}');
        }
      } else {
        debugPrint(
          'Failed to load directions. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching directions: $e');
    }
    return null;
  }
}
