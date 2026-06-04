import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/map_services.dart';

class MapProvider with ChangeNotifier {
  GoogleMapController? _mapController;

  bool _isLoadingLocation = false;
  LatLng? _currentLocation;
  String? _errorMessage;

  // Active markers and polylines globally stored
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  bool get isLoadingLocation => _isLoadingLocation;
  LatLng? get currentLocation => _currentLocation;
  String? get errorMessage => _errorMessage;

  Set<Marker> get markers => _markers;
  Set<Polyline> get polylines => _polylines;

  void setMapController(GoogleMapController controller) {
    _mapController = controller;
  }

  /// Fetches current location, handles permissions using MapServices
  Future<LatLng?> fetchCurrentLocation({bool moveCamera = false}) async {
    _isLoadingLocation = true;
    _errorMessage = null;
    notifyListeners();

    try {
      Position position = await MapServices.getCurrentLocation();
      _currentLocation = LatLng(position.latitude, position.longitude);

      if (moveCamera && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _currentLocation!, zoom: 15.0),
          ),
        );
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingLocation = false;
      notifyListeners();
    }

    return _currentLocation;
  }

  /// Manage UI tracking elements externally
  void updateMarkers(Set<Marker> newMarkers) {
    _markers = newMarkers;
    notifyListeners();
  }

  void updatePolylines(Set<Polyline> newPolylines) {
    _polylines = newPolylines;
    notifyListeners();
  }

  void clearMapData() {
    _markers.clear();
    _polylines.clear();
    _errorMessage = null;
    notifyListeners();
  }

  void fitBounds(LatLngBounds bounds, {double padding = 70.0}) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, padding),
    );
  }

  void disposeMapController() {
    _mapController?.dispose();
    _mapController = null;
  }
}
