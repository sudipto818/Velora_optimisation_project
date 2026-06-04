import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';

const String _darkMapStyle = '''
[
  { "elementType": "geometry", "stylers": [{"color": "#242f3e"}] },
  { "elementType": "labels.text.stroke", "stylers": [{"color": "#242f3e"}] },
  { "elementType": "labels.text.fill", "stylers": [{"color": "#746855"}] },
  { "featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#d59563"}] },
  { "featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#d59563"}] },
  { "featureType": "road", "elementType": "geometry", "stylers": [{"color": "#38414e"}] },
  { "featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#212a37"}] },
  { "featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#9ca5b3"}] },
  { "featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#746855"}] },
  { "featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#1f2835"}] },
  { "featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{"color": "#f3d19c"}] },
  { "featureType": "water", "elementType": "geometry", "stylers": [{"color": "#17263c"}] },
  { "featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#515c6d"}] },
  { "featureType": "water", "elementType": "labels.text.stroke", "stylers": [{"color": "#17263c"}] }
]
''';

final List<Color> _tripColors = [
  const Color(0xFF00E676), // Green
  const Color(0xFF2979FF), // Blue
  const Color(0xFFFFB300), // Amber
  const Color(0xFFD500F9), // Purple
  const Color(0xFF00E5FF), // Cyan
  const Color(0xFFFF1744), // Red
];

class FleetDetailScreen extends StatefulWidget {
  final String fleetId;

  const FleetDetailScreen({super.key, required this.fleetId});

  @override
  State<FleetDetailScreen> createState() => _FleetDetailScreenState();
}

class _FleetDetailScreenState extends State<FleetDetailScreen> {
  GoogleMapController? _mapController;
  Map<String, dynamic>? _fleet;
  List<dynamic> _vehicles = [];
  List<dynamic> _employees = [];
  List<dynamic> _trips = [];
  bool _isLoading = true;
  String? _error;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  bool _trafficEnabled = false;

  String? _expandedVehicleId;
  String? _selectedTripId;
  final Map<String, List<LatLng>> _tripRoutes = {};

  final Map<Color, BitmapDescriptor> _dotIconCache = {};

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  Future<BitmapDescriptor> _getDotMarker(
    Color color,
    double devicePixelRatio,
  ) async {
    if (_dotIconCache.containsKey(color)) {
      return _dotIconCache[color]!;
    }

    final double logicalRadius = 6.0;
    final double physicalRadius = logicalRadius * devicePixelRatio;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final Paint paint = Paint()..color = color;
    canvas.drawCircle(
      Offset(physicalRadius, physicalRadius),
      physicalRadius,
      paint,
    );

    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * devicePixelRatio;
    canvas.drawCircle(
      Offset(physicalRadius, physicalRadius),
      physicalRadius,
      borderPaint,
    );

    final int physicalSize = (physicalRadius * 2).toInt();
    final ui.Image image = await pictureRecorder.endRecording().toImage(
      physicalSize,
      physicalSize,
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final Uint8List uint8List = byteData!.buffer.asUint8List();

    final double logicalSize = logicalRadius * 2;
    final icon = BitmapDescriptor.fromBytes(
      uint8List,
      size: Size(logicalSize, logicalSize),
    );
    _dotIconCache[color] = icon;
    return icon;
  }

  static const CameraPosition _kInitialPos = CameraPosition(
    target: LatLng(37.7749, -122.4194),
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final api = auth.api;

    try {
      final results = await Future.wait([
        api.fetchFleetById(widget.fleetId),
        api.fetchFleetVehicles(widget.fleetId, limit: 50),
        api.fetchFleetEmployees(widget.fleetId, limit: 50),
        api.fetchTrips(fleetId: widget.fleetId, limit: 50),
      ]);

      if (mounted) {
        setState(() {
          _fleet = results[0];
          _vehicles = (results[1])['vehicles'] ?? [];
          _employees = (results[2])['employees'] ?? [];
          _trips = (results[3])['trips'] ?? [];
        });

        _setupMapData();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _setupMapData() async {
    _markers.clear();
    _polylines.clear();
    _selectedTripId = null;

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      _lazyLoadRoutes();
    }
  }

  /// Find the closest point on a polyline to the given target.
  LatLng _findClosestPoint(LatLng target, List<LatLng> polyline) {
    double minDist = double.infinity;
    LatLng closest = polyline.first;
    for (final pt in polyline) {
      final dLat = pt.latitude - target.latitude;
      final dLng = pt.longitude - target.longitude;
      final d = dLat * dLat + dLng * dLng;
      if (d < minDist) {
        minDist = d;
        closest = pt;
      }
    }
    return closest;
  }

  Future<void> _lazyLoadRoutes() async {
    final String rawApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    final String apiKey = rawApiKey.replaceAll("'", "").replaceAll('"', '');

    if (apiKey.isEmpty) return;

    final api = Provider.of<AuthProvider>(context, listen: false).api;
    final dpr = MediaQuery.of(context).devicePixelRatio;

    Map<String, List<dynamic>> vehicleTrips = {};
    for (var trip in _trips) {
      final vId =
          trip['vehicle']?['_id'] ?? trip['vehicle']?['id'] ?? 'unknown';
      if (!vehicleTrips.containsKey(vId)) {
        vehicleTrips[vId] = [];
      }
      vehicleTrips[vId]!.add(trip);
    }

    for (var vId in vehicleTrips.keys) {
      final vTrips = vehicleTrips[vId]!;
      for (int i = 0; i < vTrips.length; i++) {
        final trip = vTrips[i];
        final tripId = trip['_id'] ?? trip['id'];
        final stops = trip['stops'] as List<dynamic>? ?? [];

        if (stops.length < 2) continue;

        List<LatLng> fullRoutePoints = [];
        final color = _tripColors[i % _tripColors.length];

        for (int j = 0; j < stops.length - 1; j++) {
          final originL = stops[j]['location']['coordinates'];
          final destL = stops[j + 1]['location']['coordinates'];

          final start = LatLng(
            (originL[1] as num).toDouble(),
            (originL[0] as num).toDouble(),
          );
          final end = LatLng(
            (destL[1] as num).toDouble(),
            (destL[0] as num).toDouble(),
          );

          try {
            final polylineStr = await api.fetchRoutePolyline(
              start,
              end,
              apiKey,
            );
            if (polylineStr != null) {
              final segmentPoints = _decodePolyline(polylineStr);
              fullRoutePoints.addAll(segmentPoints);
            }
          } catch (e) {
            debugPrint("Error fetching polyline segment for trip $tripId: $e");
          }
        }

        if (fullRoutePoints.isNotEmpty && mounted) {
          _tripRoutes[tripId.toString()] = fullRoutePoints;

          // Create markers snapped to the polyline
          final dotIcon = await _getDotMarker(color, dpr);
          final v = trip['vehicle']?['vehicleId'] ?? 'Auto';
          Set<Marker> tripMarkers = {};

          for (int j = 0; j < stops.length; j++) {
            final stopLoc = stops[j]['location']?['coordinates'];
            if (stopLoc == null || stopLoc.length < 2) continue;
            final rawLat = (stopLoc[1] as num).toDouble();
            final rawLng = (stopLoc[0] as num).toDouble();

            // Snap to the closest point on the polyline
            final snapped = _findClosestPoint(
              LatLng(rawLat, rawLng),
              fullRoutePoints,
            );

            String title = "Stop ${j + 1}: $v";
            if (j == 0)
              title = "Start: $v";
            else if (j == stops.length - 1)
              title = "End: $v";

            tripMarkers.add(
              Marker(
                markerId: MarkerId('stop_${tripId}_$j'),
                position: snapped,
                infoWindow: InfoWindow(title: title),
                icon: dotIcon,
                anchor: const Offset(0.5, 0.5),
              ),
            );
          }

          setState(() {
            _markers.addAll(tripMarkers);
            _polylines.add(
              Polyline(
                polylineId: PolylineId('route_$tripId'),
                points: fullRoutePoints,
                color: color,
                width: 5,
                jointType: JointType.round,
                geodesic: true,
              ),
            );
          });
        }
      }
    }

    _centerMap();
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  void _zoomIn() {
    _mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    _mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  void _toggleTraffic() {
    setState(() {
      _trafficEnabled = !_trafficEnabled;
    });
  }

  void _centerMap() {
    if (_polylines.isEmpty && _markers.isEmpty) return;

    double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    bool hasPoints = false;

    for (var p in _polylines) {
      for (var pt in p.points) {
        hasPoints = true;
        if (pt.latitude < minLat) minLat = pt.latitude;
        if (pt.latitude > maxLat) maxLat = pt.latitude;
        if (pt.longitude < minLng) minLng = pt.longitude;
        if (pt.longitude > maxLng) maxLng = pt.longitude;
      }
    }
    for (var m in _markers) {
      hasPoints = true;
      if (m.position.latitude < minLat) minLat = m.position.latitude;
      if (m.position.latitude > maxLat) maxLat = m.position.latitude;
      if (m.position.longitude < minLng) minLng = m.position.longitude;
      if (m.position.longitude > maxLng) maxLng = m.position.longitude;
    }

    if (!hasPoints) return;

    if (minLat == maxLat && minLng == maxLng) {
      try {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 14.0),
        );
      } catch (e) {
        debugPrint("Bounds zoom error: \$e");
      }
      return;
    }

    try {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          50.0,
        ),
      );
    } catch (e) {
      debugPrint("Bounds zoom error: $e");
    }
  }

  void _focusOnTrip(String tripId) {
    setState(() {
      _selectedTripId = tripId;
    });

    final points = _tripRoutes[tripId];
    if (points == null || points.isEmpty) return;

    double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (var pt in points) {
      if (pt.latitude < minLat) minLat = pt.latitude;
      if (pt.latitude > maxLat) maxLat = pt.latitude;
      if (pt.longitude < minLng) minLng = pt.longitude;
      if (pt.longitude > maxLng) maxLng = pt.longitude;
    }

    if (minLat == maxLat && minLng == maxLng) {
      try {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 14.0),
        );
      } catch (e) {
        debugPrint("Trip zoom error: \$e");
      }
      return;
    }

    try {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          80.0, // Ensure adequate padding
        ),
      );
    } catch (e) {
      debugPrint("Trip zoom error: $e");
    }
  }

  void _focusOnVehicleTrips(String vehicleId) {
    setState(() {
      _selectedTripId = null;
    });

    final vTrips = _trips.where((t) {
      final vid = t['vehicle']?['_id'] ?? t['vehicle']?['id'];
      return vid == vehicleId;
    }).toList();

    if (vTrips.isEmpty) return;

    double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    bool hasPoints = false;

    for (var t in vTrips) {
      final tId = t['_id'] ?? t['id'];
      final points = _tripRoutes[tId.toString()];
      if (points != null) {
        for (var pt in points) {
          hasPoints = true;
          if (pt.latitude < minLat) minLat = pt.latitude;
          if (pt.latitude > maxLat) maxLat = pt.latitude;
          if (pt.longitude < minLng) minLng = pt.longitude;
          if (pt.longitude > maxLng) maxLng = pt.longitude;
        }
      }
    }

    if (!hasPoints) return;

    if (minLat == maxLat && minLng == maxLng) {
      try {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 14.0),
        );
      } catch (e) {
        debugPrint("Vehicle group zoom error: \$e");
      }
      return;
    }

    try {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          80.0,
        ),
      );
    } catch (e) {
      debugPrint("Vehicle group zoom error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: Text(_fleet?['fleetId'] ?? "Fleet Map"),
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadAll,
                    child: const Text("Retry"),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                _buildGoogleMap(),
                _buildMapControls(),
                _buildBottomSheet(),
              ],
            ),
    );
  }

  Widget _buildGoogleMap() {
    Set<Marker> markersToShow = _selectedTripId == null
        ? _markers
        : _markers
              .where(
                (m) => m.markerId.value.startsWith('stop_${_selectedTripId}_'),
              )
              .toSet();

    Set<Polyline> polylinesToShow = _selectedTripId == null
        ? _polylines
        : _polylines
              .where((p) => p.polylineId.value == 'route_$_selectedTripId')
              .toSet();

    return GoogleMap(
      initialCameraPosition: _kInitialPos,
      style: _darkMapStyle,
      mapType: MapType.normal,
      trafficEnabled: _trafficEnabled,
      markers: markersToShow,
      polylines: polylinesToShow,
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      onTap: (_) {
        if (_selectedTripId != null) {
          setState(() {
            _selectedTripId = null;
          });
          _centerMap();
        }
      },
      onMapCreated: (controller) {
        _mapController = controller;
        if (!_isLoading) {
          Future.delayed(const Duration(milliseconds: 300), _centerMap);
        }
      },
    );
  }

  Widget _buildMapControls() {
    return Positioned(
      right: 16,
      top: 100,
      child: Column(
        children: [
          _controlBtn(Icons.traffic, _toggleTraffic, isActive: _trafficEnabled),
          const SizedBox(height: 8),
          _controlBtn(Icons.add, _zoomIn),
          const SizedBox(height: 8),
          _controlBtn(Icons.remove, _zoomOut),
          const SizedBox(height: 8),
          _controlBtn(Icons.center_focus_strong, _centerMap),
        ],
      ),
    );
  }

  Widget _controlBtn(
    IconData icon,
    VoidCallback onTap, {
    bool isActive = false,
  }) {
    return FloatingActionButton(
      heroTag: icon.toString(),
      mini: true,
      backgroundColor: isActive ? AppTheme.primary : AppTheme.surface,
      foregroundColor: isActive ? Colors.white : AppTheme.primary,
      onPressed: onTap,
      child: Icon(icon),
    );
  }

  Widget _buildBottomSheet() {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.4,
      minChildSize: 0.17,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.17, 0.4, 0.85],
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF141414),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        children: [
                          const Text(
                            "Fleet Details",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${_trips.length} Total Trips",
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: true,
                child: DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      const TabBar(
                        indicatorColor: AppTheme.primary,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white54,
                        tabs: [
                          Tab(text: "Trips"),
                          Tab(text: "Info"),
                          Tab(text: "Staff"),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildVehicleList(),
                            _buildInfoTab(),
                            _buildEmployeesTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoTab() {
    final days = (_fleet?['weekdays'] as List<dynamic>?)?.join(', ') ?? 'N/A';
    final weightCost = _fleet?['objectiveCostWeight'] ?? 0.5;
    final weightTime = _fleet?['objectiveTimeWeight'] ?? 0.5;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _infoCard("Configuration", [
          _infoRow("Days Active", days),
          const Divider(color: Colors.white12),
          _infoRow("Cost Weight", weightCost.toString()),
          const Divider(color: Colors.white12),
          _infoRow("Time Weight", weightTime.toString()),
        ]),
      ],
    );
  }

  Widget _infoCard(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeesTab() {
    if (_employees.isEmpty) {
      return const Center(
        child: Text(
          "No employees scheduled.",
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _employees.length,
      itemBuilder: (context, index) {
        final empData = _employees[index];
        final actualEmp = empData['employee'] ?? empData;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryLight,
              child: Text(
                (actualEmp['name'] ?? '?')[0].toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              actualEmp['name'] ?? 'Unknown',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              actualEmp['employeeId'] ?? actualEmp['email'] ?? 'No ID',
              style: const TextStyle(color: Colors.white54),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVehicleList() {
    if (_vehicles.isEmpty) {
      return const Center(
        child: Text(
          "No vehicles attached.",
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _vehicles.length,
      itemBuilder: (context, index) {
        final v = _vehicles[index];
        final vId = v['_id'] ?? v['id'] ?? '';
        final vName = v['vehicleId'] ?? 'Auto';

        final vTrips = _trips.where((t) {
          final tVid = t['vehicle']?['_id'] ?? t['vehicle']?['id'];
          return tVid == vId;
        }).toList();

        return _buildVehicleTile(vId.toString(), vName.toString(), vTrips);
      },
    );
  }

  Widget _buildVehicleTile(String vId, String vName, List<dynamic> vTrips) {
    final isExpanded = _expandedVehicleId == vId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded ? Colors.white24 : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _focusOnVehicleTrips(vId);
                } else {
                  _expandedVehicleId = vId;
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A2F),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.local_shipping_outlined,
                      color: Color(0xFF4CAF50),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A2F),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "Scheduled",
                            style: TextStyle(
                              color: Color(0xFF4CAF50),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${vTrips.length} trips",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            ...vTrips.asMap().entries.map((entry) {
              final index = entry.key;
              final trip = entry.value;
              final color = _tripColors[index % _tripColors.length];
              return _buildTripItem(trip, index, color);
            }),
          if (isExpanded) const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildTripItem(dynamic trip, int index, Color color) {
    final startTime = trip['startTime'] ?? '--:--';
    final tripId = trip['_id'] ?? trip['id'] ?? '';
    final distance = trip['totalDistance'] != null
        ? "${trip['totalDistance']} km"
        : "-- km";

    final stops = trip['stops'] as List<dynamic>? ?? [];
    int riders = stops.where((s) => s['stopType'] == 'pickup').length;
    if (riders == 0 && stops.isNotEmpty) riders = stops.length - 1;

    return InkWell(
      onTap: () {
        _focusOnTrip(tripId.toString());
        _sheetController.animateTo(
          0.15,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF252525),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: color, width: 5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, color: color, size: 10),
                const SizedBox(width: 8),
                Text(
                  "Trip ${index + 1}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  startTime,
                  style: const TextStyle(color: Colors.white54, fontSize: 15),
                ),
                const Spacer(),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white30,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  color: Colors.white54,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  "$riders rider${riders != 1 ? 's' : ''}",
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.arrow_forward,
                  color: Colors.white54,
                  size: 14,
                ),
                const SizedBox(width: 16),
                Text(
                  distance,
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
