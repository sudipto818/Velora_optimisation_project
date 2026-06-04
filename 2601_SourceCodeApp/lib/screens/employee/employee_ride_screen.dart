import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../providers/auth_provider.dart';
import '../../providers/map_provider.dart';
import '../../services/map_services.dart';
import '../../utils/app_theme.dart';

class EmployeeRideScreen extends StatefulWidget {
  final String tripId;
  const EmployeeRideScreen({super.key, required this.tripId});

  @override
  State<EmployeeRideScreen> createState() => _EmployeeRideScreenState();
}

class _EmployeeRideScreenState extends State<EmployeeRideScreen> {
  Map<String, dynamic>? _trip;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Clear old map data immediately to avoid artifacts from previous screens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MapProvider>(context, listen: false).clearMapData();
    });
    _loadTripData();
  }

  // Safe helper to extract employee IDs avoiding NoSuchMethod errors
  String _getEmpId(dynamic emp) {
    if (emp == null) return '';
    if (emp is Map)
      return emp['_id']?.toString() ?? emp['id']?.toString() ?? '';
    if (emp is String) return emp;
    return '';
  }

  Future<void> _loadTripData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    final String rawApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    final String apiKey = rawApiKey.replaceAll("'", "").replaceAll('"', '');

    try {
      final tripData = await auth.api.fetchTripById(widget.tripId);
      if (mounted) {
        _trip = tripData;

        // Wait for both tasks: fetching polyline from MapServices and building markers
        await Future.wait([
          _fetchRoutePolyline(apiKey, auth, mapProvider),
          _buildCustomMarkers(mapProvider),
        ]);

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
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

  Future<BitmapDescriptor> _createCustomMarkerBitmap(
    Color bgColor, {
    IconData? iconData,
    bool isSmallInner = false,
  }) async {
    // Significantly reduced size for a hyper-minimal look
    final int size = 32;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final double radius = size / 2;

    // Subtle, clean drop shadow to lift it off the map
    final Path shadowPath = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(radius, radius), radius: radius - 1.5),
      );
    canvas.drawShadow(shadowPath, Colors.black, 3.0, true);

    // Clean white outer border (standard for modern map apps)
    final Paint whiteBorderPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(radius, radius), radius - 1, whiteBorderPaint);

    // Inner vibrant color
    final Paint fillPaint = Paint()..color = bgColor;
    canvas.drawCircle(Offset(radius, radius), radius - 3.5, fillPaint);

    // Minimalist inner detail
    if (isSmallInner) {
      final Paint dotPaint = Paint()..color = const Color(0xFF1E2736);
      canvas.drawCircle(Offset(radius, radius), radius / 4.5, dotPaint);
    } else if (iconData != null) {
      TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
      textPainter.text = TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontSize: size * 0.42, // Perfectly scaled down
          fontFamily: iconData.fontFamily,
          package: iconData.fontPackage,
          color: const Color(0xFF1E2736),
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(radius - textPainter.width / 2, radius - textPainter.height / 2),
      );
    }

    final ui.Image image = await pictureRecorder.endRecording().toImage(
      size,
      size,
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final Uint8List uint8List = byteData!.buffer.asUint8List();

    return BitmapDescriptor.bytes(uint8List);
  }

  Future<void> _buildCustomMarkers(MapProvider mapProvider) async {
    if (_trip == null || _trip!['stops'] == null) return;

    final stops = _trip!['stops'] as List<dynamic>;
    final currentUserId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).userId;
    Set<Marker> newMarkers = {};
    int myPickupIndex = -1;

    for (int i = 0; i < stops.length; i++) {
      final employeeId = _getEmpId(stops[i]['employee']);
      if (stops[i]['stopType'] != 'dropoff' && employeeId == currentUserId) {
        myPickupIndex = i;
        break;
      }
    }

    final startIndex = myPickupIndex >= 0 ? myPickupIndex : 0;
    final relevantStops = stops.sublist(startIndex);

    for (int i = 0; i < relevantStops.length; i++) {
      final stop = relevantStops[i];
      final loc = stop['location'];
      if (loc == null ||
          loc['coordinates'] == null ||
          (loc['coordinates'] as List).length < 2)
        continue;

      final coords = loc['coordinates'];
      final isDropoff = stop['stopType'] == 'dropoff';
      final employeeId = _getEmpId(stop['employee']);
      final isMyPickup = !isDropoff && employeeId == currentUserId;

      Color bgColor;
      IconData? iconData;
      bool isSmallInner = false;

      if (isDropoff) {
        bgColor = const Color(0xFFE3E8F0);
        iconData = Icons.featured_play_list_outlined;
      } else if (isMyPickup) {
        bgColor = const Color(0xFF81C784);
        iconData = Icons.person_outline;
      } else {
        bgColor = const Color(0xFFFFD54F);
        isSmallInner = true;
      }

      final BitmapDescriptor markerIcon = await _createCustomMarkerBitmap(
        bgColor,
        iconData: iconData,
        isSmallInner: isSmallInner,
      );

      String title = isDropoff ? "Office Dropoff" : "Pickup Stop";
      if (isMyPickup) title = "Your Pickup";

      newMarkers.add(
        Marker(
          markerId: MarkerId('stop_$i'),
          position: LatLng(
            (coords[1] as num).toDouble(),
            (coords[0] as num).toDouble(),
          ),
          icon: markerIcon,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: isMyPickup ? 2 : 1,
          infoWindow: InfoWindow(
            title: title,
            snippet: "Planned: ${stop['plannedTime'] ?? 'N/A'}",
          ),
        ),
      );
    }

    if (mounted) {
      mapProvider.updateMarkers(newMarkers);
    }
  }

  Future<void> _fetchRoutePolyline(
    String apiKey,
    AuthProvider auth,
    MapProvider mapProvider,
  ) async {
    if (apiKey.isEmpty || _trip == null || _trip!['stops'] == null) return;

    final stops = _trip!['stops'] as List<dynamic>;
    if (stops.length < 2) return;

    final currentUserId = auth.userId;
    int myPickupIndex = -1;

    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final employeeId = _getEmpId(stop['employee']);
      if (stop['stopType'] != 'dropoff' && employeeId == currentUserId) {
        myPickupIndex = i;
        break;
      }
    }

    final startIndex = myPickupIndex >= 0 ? myPickupIndex : 0;

    // Safely verify valid stops that have coordinates
    final relevantStops = stops.sublist(startIndex).where((s) {
      final loc = s['location'];
      return loc != null &&
          loc['coordinates'] != null &&
          (loc['coordinates'] as List).length >= 2;
    }).toList();

    if (relevantStops.length < 2) return;

    try {
      final originL = relevantStops.first['location']['coordinates'];
      final start = LatLng(
        (originL[1] as num).toDouble(),
        (originL[0] as num).toDouble(),
      );

      final destL = relevantStops.last['location']['coordinates'];
      final end = LatLng(
        (destL[1] as num).toDouble(),
        (destL[0] as num).toDouble(),
      );

      final polylineStr = await MapServices.fetchRoutePolyline(
        start,
        end,
        apiKey,
      );
      if (polylineStr != null && mounted) {
        final decodedPoints = _decodePolyline(polylineStr);
        final polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: decodedPoints,
            color: AppTheme.primary,
            width: 5,
            jointType: JointType.round,
            geodesic: true,
          ),
        };
        mapProvider.updatePolylines(polylines);
      }
    } catch (e) {
      debugPrint("❌ MapService polyline error: $e");
    }
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

  void _fitMapBounds(MapProvider mapProvider) {
    if (mapProvider.polylines.isEmpty && mapProvider.markers.isEmpty) return;

    double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    bool hasPoints = false;

    for (var p in mapProvider.polylines) {
      for (var pt in p.points) {
        hasPoints = true;
        if (pt.latitude < minLat) minLat = pt.latitude;
        if (pt.latitude > maxLat) maxLat = pt.latitude;
        if (pt.longitude < minLng) minLng = pt.longitude;
        if (pt.longitude > maxLng) maxLng = pt.longitude;
      }
    }

    for (var m in mapProvider.markers) {
      hasPoints = true;
      if (m.position.latitude < minLat) minLat = m.position.latitude;
      if (m.position.latitude > maxLat) maxLat = m.position.latitude;
      if (m.position.longitude < minLng) minLng = m.position.longitude;
      if (m.position.longitude > maxLng) maxLng = m.position.longitude;
    }

    if (!hasPoints) return;

    // Fallback if there's only 1 point
    if (minLat == maxLat && minLng == maxLng) {
      mapProvider.fitBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.01, minLng - 0.01),
          northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
        ),
      );
      return;
    }

    mapProvider.fitBounds(
      LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      ),
      padding: 70.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text("Trip Details")),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : _error != null
          ? _buildErrorState(w)
          : Stack(
              children: [
                Positioned.fill(
                  child: _buildMap(),
                ), // Crucial layout fix to make map visible
                _buildBottomSheet(w),
              ],
            ),
    );
  }

  Widget _buildBottomSheet(double w) {
    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.15,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    height: 5,
                    width: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: w * 0.04),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildInfoCard(w),
                    SizedBox(height: w * 0.04),
                    _buildStatsGrid(w),
                    SizedBox(height: w * 0.04),
                    _buildStopsTimeline(w),
                    SizedBox(height: w * 0.1),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState(double w) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(w * 0.1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadTripData,
              child: const Text("RETRY"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    final stops = (_trip!['stops'] as List<dynamic>?) ?? [];
    if (stops.isEmpty) {
      return const Center(
        child: Text(
          'No route details provided',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final currentUserId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).userId;

    int myPickupIndex = -1;
    for (int i = 0; i < stops.length; i++) {
      final employeeId = _getEmpId(stops[i]['employee']);
      if (stops[i]['stopType'] != 'dropoff' && employeeId == currentUserId) {
        myPickupIndex = i;
        break;
      }
    }

    // Prepare initial position safely
    double initLat = 28.6139; // Default
    double initLng = 77.2090;

    final validStops = stops.where((s) {
      final loc = s['location'];
      return loc != null &&
          loc['coordinates'] != null &&
          (loc['coordinates'] as List).length >= 2;
    }).toList();

    if (validStops.isNotEmpty) {
      int startIndex = myPickupIndex >= 0 ? myPickupIndex : 0;
      if (startIndex >= validStops.length) startIndex = 0;

      final coords = validStops[startIndex]['location']['coordinates'];
      initLat = (coords[1] as num).toDouble();
      initLng = (coords[0] as num).toDouble();
    }

    return Consumer<MapProvider>(
      builder: (context, mapProvider, child) {
        return Stack(
          children: [
            Positioned.fill(
              child: GoogleMap(
                mapType: MapType.normal, // Explicitly standard map type
                initialCameraPosition: CameraPosition(
                  target: LatLng(initLat, initLng),
                  zoom: 14,
                ),
                markers: mapProvider.markers,
                polylines: mapProvider.polylines,
                // The dark styling has been removed here to ensure it doesn't mask the background tiles
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                compassEnabled: true,
                mapToolbarEnabled: false,
                onMapCreated: (c) {
                  mapProvider.setMapController(c);
                  // Ensure map has been completely laid out before zooming
                  Future.delayed(
                    const Duration(milliseconds: 300),
                    () => _fitMapBounds(mapProvider),
                  );
                },
              ),
            ),

            if (mapProvider.markers.isNotEmpty)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF242C3B),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLegendItem(
                        _buildLegendIcon(
                          bgColor: const Color(0xFF81C784),
                          innerIcon: Icons.person_outline,
                        ),
                        "Your Pickup",
                      ),
                      _buildLegendItem(
                        _buildLegendIcon(
                          bgColor: const Color(0xFFFFD54F),
                          isSmallInner: true,
                          innerIcon: Icons.circle,
                        ),
                        "Waypoints",
                      ),
                      _buildLegendItem(
                        _buildLegendIcon(
                          bgColor: const Color(0xFFE3E8F0),
                          innerIcon: Icons.featured_play_list_outlined,
                        ),
                        "Office",
                      ),
                    ],
                  ),
                ),
              ),

            if (mapProvider.markers.isNotEmpty)
              Positioned(
                top: 90,
                right: 16,
                child: FloatingActionButton(
                  heroTag: "btn_recenter",
                  mini: true,
                  backgroundColor: AppTheme.surface,
                  foregroundColor: AppTheme.primary,
                  onPressed: () => _fitMapBounds(mapProvider),
                  child: const Icon(Icons.my_location),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildLegendItem(Widget iconWidget, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconWidget,
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendIcon({
    required Color bgColor,
    required IconData innerIcon,
    bool isSmallInner = false,
  }) {
    return Container(
      width: 18, // Hyper-minimal size to match the new markers
      height: 18,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        // Match the crisp white border of the map markers
        border: Border.all(color: Colors.white, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: isSmallInner
            ? Container(
                width: 4, // Tiny dot
                height: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E2736),
                  shape: BoxShape.circle,
                ),
              )
            : Icon(
                innerIcon,
                color: const Color(0xFF1E2736),
                size: 10,
              ), // Tiny icon
      ),
    );
  }

  Widget _buildInfoCard(double w) {
    final vehicle = _trip!['vehicle'];
    final status = _trip!['status']?.toString() ?? 'scheduled';

    final currentUserId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).userId;
    final stops = (_trip!['stops'] as List<dynamic>?) ?? [];
    String myPickupTime = _trip!['startTime'] ?? '--:--';

    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final employeeId = _getEmpId(stop['employee']);
      if (stop['stopType'] != 'dropoff' && employeeId == currentUserId) {
        myPickupTime = stop['plannedTime'] ?? myPickupTime;
        break;
      }
    }

    final tripIdStr =
        _trip!['_id']?.toString() ?? _trip!['id']?.toString() ?? '';
    final shortTripId = tripIdStr.length > 4
        ? tripIdStr.substring(tripIdStr.length - 4)
        : tripIdStr;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(w * 0.05),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shortTripId.isNotEmpty
                          ? "$shortTripId - Vehicle"
                          : 'Vehicle',
                      style: TextStyle(
                        fontSize: w * 0.05,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (vehicle != null)
                      Text(
                        "${vehicle['vehicleMode'] ?? 'Unknown'} • ${vehicle['fuelType'] ?? 'Unknown'}",
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.getStatusBackgroundColor(status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: AppTheme.getStatusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 32, color: AppTheme.surfaceHighlight),
            Row(
              children: [
                _TimeNode(label: "Departure", time: myPickupTime, w: w),
                const Spacer(),
                const Icon(
                  Icons.keyboard_double_arrow_right,
                  color: AppTheme.primary,
                  size: 24,
                ),
                const Spacer(),
                _TimeNode(
                  label: "Arrival",
                  time: _trip!['endTime'] ?? '--:--',
                  w: w,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(double w) {
    return Row(
      children: [
        _StatItem(
          label: "Distance",
          value: "${_trip!['totalDistance'] ?? '0'} km",
          icon: Icons.route,
          w: w,
        ),
        SizedBox(width: w * 0.03),
        _StatItem(
          label: "Duration",
          value: "${_trip!['totalDuration']?.toStringAsFixed(0) ?? '0'} min",
          icon: Icons.timer_outlined,
          w: w,
        ),
      ],
    );
  }

  Widget _buildStopsTimeline(double w) {
    final stops = (_trip!['stops'] as List<dynamic>?) ?? [];
    final currentUserId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).userId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            "Route Itinerary",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        ...stops.map((stop) {
          final isDrop = stop['stopType'] == 'dropoff';
          final status = stop['status'] ?? 'pending';
          final employeeId = _getEmpId(stop['employee']);
          final isMyPickup = !isDrop && employeeId == currentUserId;

          Color iconBgColor;
          Color iconColor;
          IconData stopIcon;

          if (isDrop) {
            iconBgColor = const Color(0xFFE3E8F0).withValues(alpha: 0.2);
            iconColor = const Color(0xFFE3E8F0);
            stopIcon = Icons.featured_play_list_outlined;
          } else if (isMyPickup) {
            iconBgColor = const Color(0xFF81C784).withValues(alpha: 0.2);
            iconColor = const Color(0xFF81C784);
            stopIcon = Icons.person_outline;
          } else {
            iconBgColor = const Color(0xFFFFD54F).withValues(alpha: 0.2);
            iconColor = const Color(0xFFFFD54F);
            stopIcon = Icons.adjust;
          }

          final empNameStr = stop['employee'] is Map
              ? stop['employee']['name']
              : '';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isMyPickup
                  ? AppTheme.surfaceHighlight.withValues(alpha: 0.8)
                  : AppTheme.surfaceHighlight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isMyPickup
                    ? const Color(0xFF81C784).withValues(alpha: 0.5)
                    : AppTheme.divider,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(stopIcon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDrop
                            ? "Office Destination"
                            : (isMyPickup
                                  ? "Your Pickup"
                                  : "Pickup: ${empNameStr ?? 'E-ID: ${(employeeId.isNotEmpty ? employeeId : '????').substring(0, 4)}'}"),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isMyPickup
                              ? const Color(0xFF81C784)
                              : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Planned: ${stop['plannedTime']} • Delay: ${stop['delay'] ?? 0}m",
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (status == 'completed')
                  const Icon(Icons.verified, color: AppTheme.success, size: 22),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _TimeNode extends StatelessWidget {
  final String label, time;
  final double w;
  const _TimeNode({required this.label, required this.time, required this.w});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: w * 0.03),
        ),
        Text(
          time,
          style: TextStyle(
            fontSize: w * 0.05,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final double w;
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.w,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: 24),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
