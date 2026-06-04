import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';

class VehicleDetailScreen extends StatefulWidget {
  final String vehicleId;

  const VehicleDetailScreen({super.key, required this.vehicleId});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  Map<String, dynamic>? _vehicle;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final api = Provider.of<AuthProvider>(context, listen: false).api;

    try {
      final data = await api.fetchVehicleById(widget.vehicleId);
      if (mounted) {
        setState(() {
          _vehicle = data;
          _isLoading = false;
        });
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

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Text(_vehicle?['vehicleId'] ?? 'Vehicle Details'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            SizedBox(height: w * 0.03),
            ElevatedButton(
              onPressed: _load,
              child: const Text("Retry"),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: EdgeInsets.all(w * 0.04),
        child: Column(
          children: [
            // Icon Header
            CircleAvatar(
              radius: w * 0.09,
              backgroundColor: AppTheme.getStatusBackgroundColor(_vehicle?['vehicleMode']),
              child: Icon(
                _modeIcon(_vehicle?['vehicleMode']),
                color: AppTheme.getStatusColor(_vehicle?['vehicleMode']),
                size: w * 0.09,
              ),
            ),
            SizedBox(height: w * 0.03),
            Text(
              _vehicle?['vehicleId'] ?? 'N/A',
              style: TextStyle(
                  fontSize: w * 0.055, fontWeight: FontWeight.bold),
            ),
            _statusBadge(_vehicle?['availabilityStatus'] ?? 'available', w),
            SizedBox(height: w * 0.06),

            // Basic Info
            _sectionCard("Vehicle Info", [
              _row("Mode", _vehicle?['vehicleMode'] ?? 'N/A', w),
              _row("Fuel Type", _vehicle?['fuelType'] ?? 'N/A', w),
              _row("Capacity",
                  "${_vehicle?['seatingCapacity'] ?? 0} seats", w),
              _row("Type", _vehicle?['vehicleType'] ?? 'N/A', w),
              _row("Cost/Km",
                  "\u20B9${_vehicle?['costPerKm'] ?? 0}/km", w),
            ], w),
            SizedBox(height: w * 0.03),

            // Performance
            if (_vehicle?['performance'] != null)
              _sectionCard("Performance", [
                _row("Avg Mileage",
                    "${_vehicle!['performance']['averageMileage'] ?? 'N/A'} km/l", w),
                _row("Avg Speed",
                    "${_vehicle!['performance']['averageSpeed'] ?? 'N/A'} km/h", w),
                _row("Vehicle Age",
                    "${_vehicle!['performance']['vehicleAge'] ?? 'N/A'} years", w),
              ], w),
            SizedBox(height: w * 0.03),

            // Location
            if (_vehicle?['currentLocation']?['coordinates'] != null)
              _sectionCard("Location", [
                _row("Longitude",
                    "${_vehicle!['currentLocation']['coordinates'][0]}", w),
                _row("Latitude",
                    "${_vehicle!['currentLocation']['coordinates'][1]}", w),
              ], w),
          ],
        ),
      ),
    );
  }

  IconData _modeIcon(String? mode) {
    switch (mode) {
      case '2-wheeler':
        return Icons.two_wheeler;
      case 'van':
        return Icons.airport_shuttle;
      default:
        return Icons.directions_car;
    }
  }

  Widget _statusBadge(String status, double w) {
    final color = AppTheme.getStatusColor(status);
    return Container(
      margin: EdgeInsets.only(top: w * 0.02),
      padding: EdgeInsets.symmetric(horizontal: w * 0.035, vertical: w * 0.012),
      decoration: BoxDecoration(
        color: color.withAlpha(26), // 0.1
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
            color: color, fontWeight: FontWeight.bold, fontSize: w * 0.03),
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> rows, double w) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(w * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: w * 0.04)),
            Divider(height: w * 0.05, color: AppTheme.divider),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, double w) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: w * 0.012),
      child: Row(
        children: [
          SizedBox(
            width: w * 0.3,
            child: Text(label,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: w * 0.035)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: w * 0.035)),
          ),
        ],
      ),
    );
  }
}