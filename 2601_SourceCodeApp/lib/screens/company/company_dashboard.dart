import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import 'company_analytics_tab.dart';
import 'company_reports_tab.dart'; // Make sure this file exists from the previous step

class CompanyDashboard extends StatefulWidget {
  const CompanyDashboard({super.key});

  @override
  State<CompanyDashboard> createState() => _CompanyDashboardState();
}

class _CompanyDashboardState extends State<CompanyDashboard> {
  Map<String, dynamic> _dashData = {};
  List<dynamic> _allFleets = [];
  Map<String, int> _vehiclesPerFleet = {}; // fleet objectId -> count
  Map<String, int> _weeklyActivity = {
    'Mon': 0,
    'Tue': 0,
    'Wed': 0,
    'Thu': 0,
    'Fri': 0,
    'Sat': 0,
    'Sun': 0,
  };
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
      final data = await auth.api.fetchCompanyDashboard(auth.userId!);
      final fleetsData = await auth.api.fetchCompanyFleets(
        auth.userId!,
        limit: 100,
      );
      final vehiclesData = await auth.api.fetchCompanyVehicles(
        auth.userId!,
        limit: 1000,
      );

      final fleetsList = fleetsData['fleets'] as List<dynamic>? ?? [];
      final vehiclesList = vehiclesData['vehicles'] as List<dynamic>? ?? [];

      Map<String, int> vPerF = {};
      Map<String, String> fIdMap = {};
      Map<String, int> wDayCounts = {
        'Mon': 0,
        'Tue': 0,
        'Wed': 0,
        'Thu': 0,
        'Fri': 0,
        'Sat': 0,
        'Sun': 0,
      };

      for (var f in fleetsList) {
        final id = f['_id']?.toString() ?? f['id']?.toString() ?? '';

        // Shorten the display ID: FLEET-{last 4 of id} if it's a long Mongo ID
        String displayId = f['fleetId']?.toString() ?? id;
        if (displayId.length > 10) {
          final last4 = displayId.substring(displayId.length - 4).toUpperCase();
          displayId = "FLEET-$last4";
        }
        fIdMap[id] = displayId;

        final List<dynamic> days = f['weekdays'] ?? [];
        for (var d in days) {
          final dayStr = d.toString();
          if (wDayCounts.containsKey(dayStr)) {
            wDayCounts[dayStr] = wDayCounts[dayStr]! + 1;
          }
        }
      }

      for (var v in vehiclesList) {
        final fId = v['fleet']?.toString() ?? '';
        if (fId.isNotEmpty) {
          vPerF[fId] = (vPerF[fId] ?? 0) + 1;
        }
      }

      if (mounted) {
        setState(() {
          _dashData = data;
          _allFleets = fleetsList;
          _vehiclesPerFleet = vPerF;
          _weeklyActivity = wDayCounts;
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
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;
    final auth = Provider.of<AuthProvider>(context);
    final companyName =
        _dashData['company']?['name'] ?? auth.userName ?? 'Company Dashboard';
    final stats = _dashData['stats'] ?? {};

    return DefaultTabController(
      length: 3, // Changed from 2 to 3 for the new Reports tab
      child: Scaffold(
        backgroundColor: Colors.black, // Dark aesthetic for dashboard body
        appBar: AppBar(
          title: Text(companyName),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () => auth.logout(),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: "Overview"),
              Tab(text: "Analytics"),
              Tab(text: "Reports"), // New Tab
            ],
          ),
        ),
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
                    SizedBox(height: h * 0.015),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: h * 0.02),
                    ElevatedButton(
                      onPressed: _loadData,
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              )
            : TabBarView(
                children: [
                  // Tab 1: Original Dashboard Overview
                  RefreshIndicator(
                    onRefresh: _loadData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(w * 0.04),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Quick Actions / Overview Row
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  title: "Employees",
                                  value: "${stats['totalEmployees'] ?? 0}",
                                  icon: Icons.people,
                                  color: AppTheme.success,
                                  width: double.infinity,
                                  onTap: () =>
                                      context.push('/company/employees'),
                                ),
                              ),
                              SizedBox(width: w * 0.03),
                              Expanded(
                                child: _StatCard(
                                  title: "Vehicles",
                                  value: "${stats['totalVehicles'] ?? 0}",
                                  icon: Icons.directions_car,
                                  color: AppTheme.secondary,
                                  width: double.infinity,
                                  onTap: () =>
                                      context.push('/company/vehicles'),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: h * 0.04),

                          // Graphs Section
                          Column(
                            children: [
                              AspectRatio(
                                aspectRatio: 1.5,
                                child: _buildWeeklyActivityChart(),
                              ),
                            ],
                          ),
                          SizedBox(height: h * 0.04),

                          // Active Fleets Section
                          _buildActiveFleetsList(w),
                          SizedBox(height: h * 0.1),
                        ],
                      ),
                    ),
                  ),

                  // Tab 2: Analytics Tab
                  CompanyAnalyticsTab(allFleets: _allFleets),

                  // Tab 3: New Reports Tab
                  CompanyReportsTab(allFleets: _allFleets),
                ],
              ),
      ),
    );
  }

  Widget _buildWeeklyActivityChart() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    double maxY = 4.0;
    for (var val in _weeklyActivity.values) {
      if (val > maxY) maxY = val.toDouble();
    }
    // Round to next even integer if needed for neat scaling
    maxY = (maxY + 1).ceilToDouble();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.calendar_today, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                "Weekly Fleet Activity",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            days[value.toInt()],
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        if (value % 1 != 0) return const SizedBox();
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return const FlLine(
                      color: Colors.white10,
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: days.asMap().entries.map((entry) {
                  int index = entry.key;
                  String day = entry.value;
                  double val = _weeklyActivity[day]?.toDouble() ?? 0;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: val,
                        color: const Color(0xFF0D9B71), // green aesthetic
                        width: 22,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFleetsList(double w) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.list_alt, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Active Fleets",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => context.push('/company/upload'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text(
                  "Create Fleet",
                  style: TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9B71),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: const Size(0, 36),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Table Header
          Row(
            children: const [
              Expanded(
                flex: 2,
                child: Text(
                  "Fleet ID",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 6,
                child: Text(
                  "Schedule",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "Vehicles",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "Actions",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 8),
          if (_allFleets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  "No Active Fleets",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ..._allFleets.map((fleet) {
              final oId =
                  fleet['_id']?.toString() ?? fleet['id']?.toString() ?? '';
              String displayId = fleet['fleetId']?.toString() ?? oId;
              if (displayId.length > 4) {
                final last4 = displayId
                    .substring(displayId.length - 4)
                    .toUpperCase();
                displayId = last4;
              }
              final days = List<String>.from(fleet['weekdays'] ?? []);
              final vCount = _vehiclesPerFleet[oId] ?? 0;

              return Column(
                children: [
                  InkWell(
                    onTap: () {
                      if (oId.isNotEmpty) context.push('/fleet/$oId');
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              displayId,
                              style: const TextStyle(
                                color: Color(0xFF0D9B71),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 6,
                            child: Wrap(
                              spacing: 1,
                              runSpacing: 2,
                              children:
                                  [
                                    'Mon',
                                    'Tue',
                                    'Wed',
                                    'Thu',
                                    'Fri',
                                    'Sat',
                                    'Sun',
                                  ].map((d) {
                                    bool active = days.contains(d);
                                    return Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: active
                                            ? const Color(0xFF0D9B71)
                                            : const Color(0xFF222222),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        d[0], // Extract first letter M, T, W...
                                        style: TextStyle(
                                          color: active
                                              ? Colors.black
                                              : Colors.grey,
                                          fontSize: 9,
                                          fontWeight: active
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF222222),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.directions_car_outlined,
                                    color: Colors.grey,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      "$vCount",
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 10,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text("Delete Fleet"),
                                      content: const Text(
                                        "Are you sure you want to delete this fleet? This action is irreversible.",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text("Cancel"),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            Navigator.pop(ctx);
                                            try {
                                              final auth =
                                                  Provider.of<AuthProvider>(
                                                    context,
                                                    listen: false,
                                                  );
                                              await auth.api.deleteFleet(oId);
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Fleet deleted successfully',
                                                    ),
                                                    backgroundColor:
                                                        AppTheme.success,
                                                  ),
                                                );
                                                _loadData();
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Error: ${e.toString().replaceAll('Exception: ', '')}',
                                                    ),
                                                    backgroundColor:
                                                        AppTheme.error,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          child: const Text(
                                            "Delete",
                                            style: TextStyle(
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red.shade400,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double width;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.width,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF111111), // dark mode
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
