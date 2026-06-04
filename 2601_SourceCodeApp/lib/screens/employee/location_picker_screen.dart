import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/map_provider.dart';
import '../../utils/app_theme.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final String title;

  const LocationPickerScreen({
    super.key,
    this.initialLocation,
    this.title = "Choose Location",
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng _currentCameraPosition = const LatLng(
    28.6139,
    77.2090,
  ); // Default to New Delhi

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _currentCameraPosition = widget.initialLocation!;
    }
  }

  Future<void> _getCurrentLocation() async {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    mapProvider.setMapController(_mapController!);

    final newLoc = await mapProvider.fetchCurrentLocation(moveCamera: true);
    if (newLoc != null && mounted) {
      setState(() {
        _currentCameraPosition = newLoc;
      });
    }

    if (mapProvider.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mapProvider.errorMessage!),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () {
              // Return the center position
              Navigator.of(context).pop(_currentCameraPosition);
            },
            child: const Text(
              "Confirm",
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentCameraPosition,
              zoom: 14.0,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: (position) {
              _currentCameraPosition = position.target;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // We use custom button
            zoomControlsEnabled: false,
          ),
          // Center Marker
          Center(
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: 35.0,
              ), // Adjust for pin pointing exactly at center
              child: Icon(Icons.location_on, size: 50, color: AppTheme.primary),
            ),
          ),
          Consumer<MapProvider>(
            builder: (context, mapProvider, child) {
              if (mapProvider.isLoadingLocation) {
                return const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.primary,
        tooltip: "Locate Me",
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
