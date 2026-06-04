import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import 'location_picker_screen.dart';

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _rideDetails;
  List<dynamic> _assignments = [];
  String? _pendingTripId;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.userId == null) return;

    try {
      final results = await Future.wait([
        auth.api.fetchEmployeeProfile(auth.userId!),
        auth.api.fetchEmployeeRideDetails(auth.userId!),
        auth.api.fetchEmployeeFleets(auth.userId!),
        auth.api.fetchTrips(
          employeeId: auth.userId!,
          limit: 5,
        ), // Fetch recent trips
      ]);

      if (mounted) {
        setState(() {
          _profile = results[0];
          _rideDetails = results[1];
          _assignments = results[2]['assignments'] ?? [];

          final tripsResponse = results[3] as Map<String, dynamic>?;
          final trips = tripsResponse?['trips'] as List<dynamic>? ?? [];

          // Find first active or scheduled trip
          final activeTrip = trips.firstWhere(
            (t) =>
                t['status'] == 'scheduled' ||
                t['status'] == 'ongoing' ||
                t['status'] == 'active',
            orElse: () => null,
          );

          _pendingTripId = activeTrip?['_id'];
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

  Future<void> _submitDynamicUpdate({
    String? earliestPickup,
    String? latestDrop,
    String? vehiclePref,
    String? sharingPref,
    LatLng? pickupLocation,
    LatLng? dropLocation,
  }) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final employeeData = _profile?['employee'];
      String companyId = '';
      if (employeeData != null) {
        final comp = employeeData['company'];
        if (comp is Map) {
          companyId = comp['_id']?.toString() ?? '';
        } else if (comp is String) {
          companyId = comp;
        }
      }

      if (companyId.isEmpty && _assignments.isNotEmpty) {
        final fleetComp = _assignments[0]['fleet']?['company'];
        if (fleetComp is Map) {
          companyId = fleetComp['_id']?.toString() ?? '';
        } else if (fleetComp is String) {
          companyId = fleetComp;
        }
      }

      String fleetId = '';
      final fleetInfo = _rideDetails?['fleetInfo'];
      if (fleetInfo is Map) {
        fleetId = fleetInfo['_id']?.toString() ?? '';
      } else if (fleetInfo is String) {
        fleetId = fleetInfo;
      }

      if (fleetId.isEmpty && _assignments.isNotEmpty) {
        final fleet = _assignments[0]['fleet'];
        if (fleet is Map) {
          fleetId = fleet['_id']?.toString() ?? '';
        } else if (fleet is String) {
          fleetId = fleet;
        }
      }

      if (companyId.isEmpty || fleetId.isEmpty) {
        throw Exception("Missing company or fleet information.");
      }

      final Map<String, dynamic> changes = {};
      if (earliestPickup != null) changes['earliest_pickup'] = earliestPickup;
      if (latestDrop != null) changes['latest_drop'] = latestDrop;
      if (vehiclePref != null) changes['vehicle_preference'] = vehiclePref;
      if (sharingPref != null) changes['sharing_preference'] = sharingPref;
      if (pickupLocation != null) {
        changes['pickup_lat'] = pickupLocation.latitude;
        changes['pickup_lng'] = pickupLocation.longitude;
      }
      if (dropLocation != null) {
        changes['drop_lat'] = dropLocation.latitude;
        changes['drop_lng'] = dropLocation.longitude;
      }

      final actualEmployeeId =
          employeeData?['employeeId']?.toString() ?? auth.userId!;

      await auth.api.submitDynamicChanges(
        companyId,
        fleetId,
        actualEmployeeId,
        changes,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Details updated successfully!')),
        );
        _loadData(); // reload dashboard
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final auth = Provider.of<AuthProvider>(context);
    final empName =
        _profile?['employee']?['name'] ?? auth.userName ?? 'Employee';
    final rideStatus = _rideDetails?['rideStatus'] ?? 'N/A';

    // Get fleetId for current ride if available
    String currentFleetId = '';
    if (_rideDetails?['fleetInfo'] != null) {
      currentFleetId = _rideDetails!['fleetInfo']['fleetId'] ?? '';
    } else if (_assignments.isNotEmpty) {
      final firstAssignmentFleet = _assignments[0]['fleet'];
      currentFleetId = firstAssignmentFleet?['fleetId'] ?? '';
    }

    String displayFleetId = currentFleetId;
    if (displayFleetId.length >= 4) {
      displayFleetId = displayFleetId.substring(displayFleetId.length - 4);
    }

    return Scaffold(
      appBar: AppBar(title: const Text("My Workspace")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: w * 0.12,
                    color: AppTheme.error,
                  ),
                  SizedBox(height: w * 0.03),
                  Text(_error!, textAlign: TextAlign.center),
                  SizedBox(height: w * 0.04),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text("Retry"),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(w * 0.04),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Card
                    _WelcomeCard(
                      empName: empName,
                      rideStatus: rideStatus,
                      width: w,
                    ),
                    SizedBox(height: w * 0.04),

                    // Current Ride Details
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Next Ride",
                          style: TextStyle(
                            fontSize: w * 0.045,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (displayFleetId.isNotEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: w * 0.02,
                              vertical: w * 0.01,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "Fleet: $displayFleetId",
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: w * 0.035,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: w * 0.02),
                    if (_rideDetails?['vehicle'] != null ||
                        _rideDetails?['schedule'] != null)
                      _RideCard(
                        width: w,
                        rideDetails: _rideDetails,
                        assignments: _assignments,
                        onSubmitUpdate: _submitDynamicUpdate,
                      ),

                    SizedBox(height: w * 0.04),

                    // Quick Actions
                    SizedBox(
                      width: double.infinity,
                      child: _QuickAction(
                        icon: Icons.directions,
                        label: "Ride Details",
                        onTap: () {
                          if (_pendingTripId != null) {
                            context.push('/employee/ride/$_pendingTripId');
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No active rides scheduled.'),
                              ),
                            );
                          }
                        },
                        width: w,
                      ),
                    ),
                    SizedBox(height: w * 0.06),
                  ],
                ),
              ),
            ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final String empName;
  final String rideStatus;
  final double width;

  const _WelcomeCard({
    required this.empName,
    required this.rideStatus,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: () => context.push('/employee/profile'),
        contentPadding: EdgeInsets.all(width * 0.05),
        title: Text(
          "Hello, $empName",
          style: TextStyle(
            color: Colors.black,
            fontSize: width * 0.055,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          "Ride Status: $rideStatus",
          style: const TextStyle(color: Colors.black54),
        ),
        trailing: const CircleAvatar(
          backgroundColor: Colors.black12,
          child: Icon(Icons.person, color: Colors.black),
        ),
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  final double width;
  final Map<String, dynamic>? rideDetails;
  final List<dynamic> assignments;
  final Future<void> Function({
    String? earliestPickup,
    String? latestDrop,
    String? vehiclePref,
    String? sharingPref,
    LatLng? pickupLocation,
    LatLng? dropLocation,
  })
  onSubmitUpdate;

  const _RideCard({
    required this.width,
    required this.rideDetails,
    required this.assignments,
    required this.onSubmitUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final vehicle = rideDetails?['vehicle'];
    final schedule = rideDetails?['schedule'];

    return Card(
      child: Padding(
        padding: EdgeInsets.all(width * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.directions_car,
                  color: AppTheme.primary,
                  size: width * 0.05,
                ),
                SizedBox(width: width * 0.02),
                Text(
                  "Next Ride",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: width * 0.04,
                  ),
                ),
                const Spacer(),
                if (schedule != null && schedule['pickupTime'] != null)
                  _TimeLeftWidget(
                    pickupTimeStr: schedule['pickupTime'],
                    width: width,
                  ),
              ],
            ),
            Divider(height: width * 0.05, color: AppTheme.divider),
            if (vehicle != null)
              Text(
                "Vehicle: ${vehicle['vehicleId'] ?? 'N/A'} (${vehicle['vehicleMode'] ?? ''})",
                style: TextStyle(fontSize: width * 0.035),
              ),
            if (schedule != null) ...[
              if (schedule['pickupTime'] != null)
                Text(
                  "Pickup: ${schedule['pickupTime']}",
                  style: TextStyle(fontSize: width * 0.035),
                ),
              if (schedule['dropTime'] != null)
                Text(
                  "Drop: ${schedule['dropTime']}",
                  style: TextStyle(fontSize: width * 0.035),
                ),
              if (schedule['days'] != null)
                Text(
                  "Days: ${(schedule['days'] as List).join(', ')}",
                  style: TextStyle(
                    fontSize: width * 0.035,
                    color: AppTheme.textSecondary,
                  ),
                ),
              SizedBox(height: width * 0.03),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.edit_location_alt, size: 20),
                  label: const Text('Edit Pickup & Ride Info'),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (sheetContext) => _EditRideDetailsSheet(
                        currentSchedule: rideDetails?['schedule'],
                        currentPrefs: assignments.isNotEmpty
                            ? assignments[0]['preferences']
                            : null,
                        onSubmit: onSubmitUpdate,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimeLeftWidget extends StatelessWidget {
  final String pickupTimeStr;
  final double width;

  const _TimeLeftWidget({required this.pickupTimeStr, required this.width});

  @override
  Widget build(BuildContext context) {
    try {
      final now = DateTime.now();
      final parts = pickupTimeStr.split(':');
      if (parts.length != 2) return const SizedBox();
      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);

      var pickupDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        hours,
        minutes,
      );
      if (pickupDateTime.isBefore(now)) {
        pickupDateTime = pickupDateTime.add(const Duration(days: 1));
      }

      final diff = pickupDateTime.difference(now);
      final hrsLeft = diff.inHours;
      final minsLeft = diff.inMinutes.remainder(60);

      String timeLeftStr = '';
      if (hrsLeft > 0) timeLeftStr += '${hrsLeft}h ';
      timeLeftStr += '${minsLeft}m left';

      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: width * 0.02,
          vertical: width * 0.01,
        ),
        decoration: BoxDecoration(
          color: AppTheme.info.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          timeLeftStr,
          style: TextStyle(
            color: AppTheme.info,
            fontWeight: FontWeight.bold,
            fontSize: width * 0.035,
          ),
        ),
      );
    } catch (e) {
      return const SizedBox();
    }
  }
}

class _EditRideDetailsSheet extends StatefulWidget {
  final Map<String, dynamic>? currentSchedule;
  final Map<String, dynamic>? currentPrefs;
  final Future<void> Function({
    String? earliestPickup,
    String? latestDrop,
    String? vehiclePref,
    String? sharingPref,
    LatLng? pickupLocation,
    LatLng? dropLocation,
  })
  onSubmit;

  const _EditRideDetailsSheet({
    this.currentSchedule,
    this.currentPrefs,
    required this.onSubmit,
  });

  @override
  State<_EditRideDetailsSheet> createState() => _EditRideDetailsSheetState();
}

class _EditRideDetailsSheetState extends State<_EditRideDetailsSheet> {
  String? earliestPickup;
  String? latestDrop;
  String vehiclePref = 'any';
  String sharingPref = 'any';
  LatLng? pickupLocation;
  LatLng? dropLocation;

  @override
  void initState() {
    super.initState();

    if (widget.currentSchedule?['pickupTime'] != null) {
      earliestPickup = widget.currentSchedule!['pickupTime'].toString();
    } else if (widget.currentPrefs?['timeWindow'] is Map) {
      earliestPickup = widget.currentPrefs!['timeWindow']['startTime']
          ?.toString();
    }

    if (widget.currentSchedule?['dropTime'] != null) {
      latestDrop = widget.currentSchedule!['dropTime'].toString();
    } else if (widget.currentPrefs?['timeWindow'] is Map) {
      latestDrop = widget.currentPrefs!['timeWindow']['endTime']?.toString();
    }

    vehiclePref =
        widget.currentPrefs?['vehiclePreference']?.toString().toLowerCase() ??
        'any';
    if (!['any', 'normal', 'premium'].contains(vehiclePref)) {
      vehiclePref = 'any';
    }

    sharingPref =
        widget.currentPrefs?['sharingPreference']?.toString().toLowerCase() ??
        'any';
    if (!['any', 'single', 'double', 'triple'].contains(sharingPref)) {
      sharingPref = 'any';
    }

    try {
      final pickupLoc = widget.currentPrefs?['pickupLocation'];
      if (pickupLoc is Map) {
        final coords = pickupLoc['coordinates'];
        if (coords is List && coords.length >= 2) {
          pickupLocation = LatLng(
            (coords[1] as num).toDouble(),
            (coords[0] as num).toDouble(),
          );
        }
      }
    } catch (e) {
      // Ignore parsing errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Edit Ride Details",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TimePickerField(
                    label: "Earliest Pickup",
                    currentTime: earliestPickup,
                    onTimeSelected: (newTime) =>
                        setState(() => earliestPickup = newTime),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _TimePickerField(
                    label: "Latest Drop",
                    currentTime: latestDrop,
                    onTimeSelected: (newTime) =>
                        setState(() => latestDrop = newTime),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _LocationPickerField(
              label: "Pickup Location",
              currentLocation: pickupLocation,
              onLocationSelected: (newLoc) =>
                  setState(() => pickupLocation = newLoc),
            ),
            const SizedBox(height: 8),
            _LocationPickerField(
              label: "Drop Location",
              currentLocation: dropLocation,
              onLocationSelected: (newLoc) =>
                  setState(() => dropLocation = newLoc),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: vehiclePref,
                    decoration: const InputDecoration(
                      labelText: "Vehicle Pref",
                      border: OutlineInputBorder(),
                    ),
                    items: ['any', 'normal', 'premium'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => vehiclePref = val!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: sharingPref,
                    decoration: const InputDecoration(
                      labelText: "Sharing Pref",
                      border: OutlineInputBorder(),
                    ),
                    items: ['any', 'single', 'double', 'triple'].map((
                      String value,
                    ) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => sharingPref = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () async {
                  Navigator.pop(context); // Close modal
                  widget.onSubmit(
                    earliestPickup: earliestPickup,
                    latestDrop: latestDrop,
                    vehiclePref: vehiclePref,
                    sharingPref: sharingPref,
                    pickupLocation: pickupLocation,
                    dropLocation: dropLocation,
                  );
                },
                child: const Text("Save Changes"),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _TimePickerField extends StatelessWidget {
  final String label;
  final String? currentTime;
  final Function(String) onTimeSelected;

  const _TimePickerField({
    required this.label,
    this.currentTime,
    required this.onTimeSelected,
  });

  String _formatTimeAmPm(String time24) {
    try {
      final parts = time24.split(':');
      final dt = DateTime(2020, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return time24;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        TimeOfDay initial = TimeOfDay.now();
        if (currentTime != null && currentTime!.contains(':')) {
          final parts = currentTime!.split(':');
          initial = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
        final TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: initial,
        );
        if (picked != null) {
          final formatted =
              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
          onTimeSelected(formatted);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(
          currentTime != null ? _formatTimeAmPm(currentTime!) : "Select Time",
        ),
      ),
    );
  }
}

class _LocationPickerField extends StatelessWidget {
  final String label;
  final LatLng? currentLocation;
  final Function(LatLng) onLocationSelected;

  const _LocationPickerField({
    required this.label,
    this.currentLocation,
    required this.onLocationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final LatLng? picked = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LocationPickerScreen(
              title: label,
              initialLocation: currentLocation,
            ),
          ),
        );
        if (picked != null) {
          onLocationSelected(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.map),
        ),
        child: Text(
          currentLocation != null
              ? "${currentLocation!.latitude.toStringAsFixed(4)}, ${currentLocation!.longitude.toStringAsFixed(4)}"
              : "Pick on Map",
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double width;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: width * 0.04),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: width * 0.07),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: width * 0.03,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
