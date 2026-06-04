import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';

class TripDetailScreen extends StatefulWidget {
  final String tripId;
  const TripDetailScreen({super.key, required this.tripId});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  Map<String, dynamic>? _trip;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    final api = Provider.of<AuthProvider>(context, listen: false).api;
    try {
      final data = await api.fetchTripById(widget.tripId);
      if (mounted) setState(() { _trip = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceAll('Exception: ', ''); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(title: const Text("Trip Details")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!), SizedBox(height: w * 0.03),
        ElevatedButton(onPressed: _load, child: const Text("Retry"))
      ]))
          : SingleChildScrollView(
        padding: EdgeInsets.all(w * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(w),
            SizedBox(height: w * 0.04),
            if (_trip?['vehicle'] != null) _buildVehicleCard(w),
            SizedBox(height: w * 0.04),
            Text("Stops", style: TextStyle(fontSize: w * 0.045, fontWeight: FontWeight.bold)),
            SizedBox(height: w * 0.03),
            _buildStops(w),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double w) {
    final status = _trip?['status'] ?? 'scheduled';
    final start = _trip?['startTime'] ?? '';
    final end = _trip?['endTime'] ?? '';
    final duration = _trip?['totalDuration'] ?? 0;
    final stops = (_trip?['stops'] as List?)?.length ?? 0;

    String dateStr = '';
    if (_trip?['date'] != null) {
      try {
        final d = DateTime.parse(_trip!['date']);
        dateStr = "${d.day}/${d.month}/${d.year}";
      } catch (_) { dateStr = _trip!['date'].toString(); }
    }

    final statusColor = AppTheme.getStatusColor(status);
    final statusBg = AppTheme.getStatusBackgroundColor(status);

    return Card(
      color: statusBg.withAlpha(15), // 0.06
      child: Padding(
        padding: EdgeInsets.all(w * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("$start \u2192 $end", style: TextStyle(fontSize: w * 0.05, fontWeight: FontWeight.bold)),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: w * 0.03, vertical: w * 0.012),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(status.toUpperCase(),
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: w * 0.028)),
                ),
              ],
            ),
            SizedBox(height: w * 0.02),
            Text("Date: $dateStr", style: const TextStyle(color: AppTheme.textSecondary)),
            Text("Duration: $duration min | $stops stops", style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard(double w) {
    final v = _trip!['vehicle'];
    return Card(
      child: ListTile(
        onTap: () {
          final id = v['_id'] ?? v['id'];
          if (id != null) context.push('/vehicle/$id');
        },
        leading: CircleAvatar(
          backgroundColor: AppTheme.warningLight,
          child: Icon(Icons.directions_car, color: AppTheme.warning, size: w * 0.05),
        ),
        title: Text(v['vehicleId'] ?? 'Vehicle', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${v['vehicleMode'] ?? ''} | ${v['fuelType'] ?? ''} | ${v['seatingCapacity'] ?? 0} seats",
            style: TextStyle(fontSize: w * 0.03)),
        trailing: Icon(Icons.chevron_right, size: w * 0.045),
      ),
    );
  }

  Widget _buildStops(double w) {
    final stops = (_trip?['stops'] as List?) ?? [];
    if (stops.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(w * 0.04),
        child: const Text("No stops recorded.", style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return Column(
      children: List.generate(stops.length, (index) {
        final stop = stops[index];
        final isPickup = stop['stopType'] == 'pickup';
        final time = stop['plannedTime'] ?? '';
        final empName = stop['employee']?['name'];
        final empEmail = stop['employee']?['email'];
        final stopStatus = stop['status'] ?? 'pending';
        final isLast = index == stops.length - 1;

        final typeColor = isPickup ? AppTheme.info : AppTheme.error;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline
              SizedBox(
                width: w * 0.09,
                child: Column(
                  children: [
                    Container(
                      width: w * 0.035, height: w * 0.035,
                      decoration: BoxDecoration(
                        color: typeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: AppTheme.divider,
                        ),
                      ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(bottom: w * 0.04),
                  padding: EdgeInsets.all(w * 0.03),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            Icon(isPickup ? Icons.arrow_upward : Icons.arrow_downward,
                                color: typeColor, size: w * 0.04),
                            SizedBox(width: w * 0.015),
                            Text(isPickup ? "PICKUP" : "DROPOFF",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: w * 0.03,
                                    color: typeColor)),
                          ]),
                          Text(time, style: TextStyle(fontWeight: FontWeight.w600, fontSize: w * 0.032)),
                        ],
                      ),
                      if (empName != null) ...[
                        SizedBox(height: w * 0.01),
                        Text(empName, style: TextStyle(fontSize: w * 0.032)),
                        if (empEmail != null)
                          Text(empEmail, style: TextStyle(fontSize: w * 0.028, color: AppTheme.textSecondary)),
                      ],
                      SizedBox(height: w * 0.01),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: w * 0.02, vertical: w * 0.005),
                        decoration: BoxDecoration(
                          color: AppTheme.getStatusBackgroundColor(stopStatus),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(stopStatus,
                            style: TextStyle(
                                color: AppTheme.getStatusColor(stopStatus),
                                fontSize: w * 0.025,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}