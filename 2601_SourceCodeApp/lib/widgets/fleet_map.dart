import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/app_theme.dart';

class FleetMap extends StatefulWidget {
  final Set<Marker> markers;
  final void Function(GoogleMapController)? onMapCreated;
  final CameraPosition? initialCameraPosition;
  final bool myLocationEnabled;

  const FleetMap({
    super.key,
    this.markers = const {},
    this.onMapCreated,
    this.initialCameraPosition,
    this.myLocationEnabled = true,
  });

  @override
  State<FleetMap> createState() => _FleetMapState();
}

class _FleetMapState extends State<FleetMap> {
  final Completer<GoogleMapController> _controllerGoogleMap = Completer();

  static const CameraPosition _kDefaultPos = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 12,
  );

  // Dark Mode Style JSON (Minified for safety)
  static const String _darkMapStyle =
      '[{"elementType":"geometry","stylers":[{"color":"#212121"}]},{"elementType":"labels.icon","stylers":[{"visibility":"off"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},{"elementType":"administrative","stylers":[{"geometry":"geometry.fill","color":"#757575"}]},{"elementType":"administrative.country","stylers":[{"geometry":"geometry.stroke","color":"#757575"}]},{"elementType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},{"elementType":"administrative.locality","stylers":[{"color":"#757575"}]},{"elementType":"poi","stylers":[{"color":"#212121"}]},{"elementType":"poi","stylers":[{"geometry":"geometry.fill","color":"#757575"}]},{"elementType":"poi.park","stylers":[{"geometry":"geometry.fill","color":"#181818"}]},{"elementType":"poi.park","stylers":[{"geometry":"geometry.stroke","color":"#1b1b1b"}]},{"elementType":"road","stylers":[{"color":"#2c2c2c"},{"lightness":-20}]},{"elementType":"road.arterial","stylers":[{"geometry":"geometry.fill","color":"#383838"}]},{"elementType":"road.highway","stylers":[{"geometry":"geometry.fill","color":"#3c3c3c"}]},{"elementType":"road.highway.controlled_access","stylers":[{"geometry":"geometry.fill","color":"#4e4e4e"}]},{"elementType":"road.local","stylers":[{"color":"#2c2c2c"},{"lightness":-20}]},{"elementType":"transit","stylers":[{"color":"#2f2f2f"}]},{"elementType":"water","stylers":[{"color":"#000000"}]}]';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: GoogleMap(
          style: _darkMapStyle, // Using the recommended style parameter
          mapType: MapType.normal,
          markers: widget.markers,
          myLocationEnabled: widget.myLocationEnabled,
          myLocationButtonEnabled: false,
          initialCameraPosition: widget.initialCameraPosition ?? _kDefaultPos,
          onMapCreated: (GoogleMapController controller) {
            _controllerGoogleMap.complete(controller);

            if (widget.onMapCreated != null) {
              widget.onMapCreated!(controller);
            }
          },
        ),
      ),
    );
  }
}