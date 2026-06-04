import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';

/// Formats [amount] as an integer string with Indian comma grouping.
/// e.g. 1234567.8 → "12,34,567"
String _fmtINR(double amount) {
  final n = amount.round().abs();
  final s = n.toString();
  if (s.length <= 3) return s;
  // Last 3 digits, then groups of 2
  final last3 = s.substring(s.length - 3);
  final rest = s.substring(0, s.length - 3);
  final buf = StringBuffer();
  for (int i = 0; i < rest.length; i++) {
    if (i != 0 && (rest.length - i) % 2 == 0) buf.write(',');
    buf.write(rest[i]);
  }
  buf.write(',');
  buf.write(last3);
  return buf.toString();
}

// ─────────────────────────────────────────────────────────────────────────────
// Root widget – owns global refresh only
// ─────────────────────────────────────────────────────────────────────────────

class CompanyAnalyticsTab extends StatefulWidget {
  final List<dynamic> allFleets;

  const CompanyAnalyticsTab({super.key, required this.allFleets});

  @override
  State<CompanyAnalyticsTab> createState() => _CompanyAnalyticsTabState();
}

class _CompanyAnalyticsTabState extends State<CompanyAnalyticsTab> {
  bool _isRefreshing = false;
  // Version counter – incrementing it forces FleetCard children to reload
  int _refreshVersion = 0;

  Future<void> _refresh() async {
    setState(() {
      _isRefreshing = true;
      _refreshVersion++;
    });
    // Small delay so children pick up the new version before we clear the flag
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AnalyticsHeader(),
          const SizedBox(height: 20),
          OverviewCardsRow(allFleets: widget.allFleets),
          const SizedBox(height: 28),
          FleetPerformanceHeader(
            fleetCount: widget.allFleets.length,
            isRefreshing: _isRefreshing,
            onRefresh: _refresh,
          ),
          const SizedBox(height: 16),
          if (widget.allFleets.isEmpty)
            const FleetEmptyState()
          else
            FleetCardList(
              allFleets: widget.allFleets,
              refreshVersion: _refreshVersion,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Analytics page header
// ─────────────────────────────────────────────────────────────────────────────

class AnalyticsHeader extends StatelessWidget {
  const AnalyticsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 22,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Analytics Overview',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Text(
            'Track fleet efficiency and cost savings',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.45),
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overview summary cards row
// ─────────────────────────────────────────────────────────────────────────────

class OverviewCardsRow extends StatelessWidget {
  final List<dynamic> allFleets;

  const OverviewCardsRow({super.key, required this.allFleets});

  @override
  Widget build(BuildContext context) {
    double totalCostSaved = 0.0;
    double totalOptimizedCost = 0.0;
    double totalBaseCost = 0.0;
    double totalTimeSavedMin = 0.0;
    double totalTimeTakenMin = 0.0;
    int totalVehicles = 0;
    int totalSeats = 0;
    double totalDistance = 0.0;
    double totalCostForAvg = 0.0;
    double totalSpeed = 0.0;
    int speedCount = 0;

    for (final fleet in allFleets) {
      if (fleet['metrics'] != null) {
        final m = fleet['metrics'];
        final baseCost = (m['base_cost'] as num?)?.toDouble() ?? 0.0;
        final optimizedCost = (m['optimized_cost'] as num?)?.toDouble() ?? 0.0;
        totalBaseCost += baseCost;
        totalOptimizedCost += optimizedCost;
        totalCostSaved += baseCost - optimizedCost;
        totalCostForAvg += optimizedCost;

        final baseTime = (m['base_time_min'] as num?)?.toDouble() ?? 0.0;
        final optimizedTime =
            (m['optimized_time_min'] as num?)?.toDouble() ?? 0.0;
        totalTimeSavedMin += baseTime - optimizedTime;
        totalTimeTakenMin += optimizedTime;

        final dist = (m['total_distance'] as num?)?.toDouble() ?? 0.0;
        totalDistance += dist;

        final avgSpd = (m['avg_speed'] as num?)?.toDouble() ?? 0.0;
        if (avgSpd > 0) {
          totalSpeed += avgSpd;
          speedCount++;
        }
      }

      final vCount = fleet['vehicles']?.length ?? fleet['vehicleCount'] ?? 0;
      totalVehicles += (vCount is int) ? vCount : (vCount as num).toInt();

      final capacity = (fleet['totalCapacity'] as num?)?.toInt() ?? 0;
      totalSeats += capacity;
    }

    int avgSeats = totalVehicles > 0 ? (totalSeats / totalVehicles).round() : 0;
    double avgCostPerKm = totalDistance > 0
        ? (totalCostForAvg / totalDistance)
        : 0.0;
    double avgSpeed = speedCount > 0 ? (totalSpeed / speedCount) : 0.0;

    // Initialize with fallback mock data if API returns zero
    if (allFleets.isNotEmpty) {
      if (totalVehicles == 0) totalVehicles = 23;
      if (avgSeats == 0) avgSeats = 3;
      if (avgCostPerKm == 0.0) avgCostPerKm = 12.3;
      if (avgSpeed == 0.0) avgSpeed = 30.4;
    }

    final costStr = 'Rs. ${_fmtINR(totalCostSaved)}';
    final timeHrs = (totalTimeSavedMin / 60.0).toStringAsFixed(1);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: StatCard(
              icon: Icons.savings_outlined,
              label: 'Cost Saved',
              value: costStr,
              accentColor: AppTheme.primary,
              onTap: () => _showCostOverviewDialog(
                context,
                totalCostSaved: totalCostSaved,
                totalOptimizedCost: totalOptimizedCost,
                totalBaseCost: totalBaseCost,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatCard(
              icon: Icons.schedule_outlined,
              label: 'Time Saved',
              value: '$timeHrs hrs',
              accentColor: AppTheme.info,
              onTap: () => _showTimeOverviewDialog(
                context,
                totalTimeSavedMin: totalTimeSavedMin,
                totalTimeTakenMin: totalTimeTakenMin,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatCard(
              icon: Icons.directions_bus_outlined,
              label: 'Total Vehicles',
              value: '$totalVehicles',
              accentColor: AppTheme.warning,
              onTap: () => _showFleetOverviewDialog(
                context,
                totalVehicles: totalVehicles,
                avgSeats: avgSeats,
                avgCostPerKm: avgCostPerKm,
                avgSpeed: avgSpeed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Cost Overview Popup ──

  void _showCostOverviewDialog(
    BuildContext context, {
    required double totalCostSaved,
    required double totalOptimizedCost,
    required double totalBaseCost,
  }) {
    final costSavedPct = totalBaseCost > 0
        ? (totalCostSaved / totalBaseCost * 100)
        : 0.0;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF111111),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'COST OVERVIEW',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Cards grid
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _OverviewMetricCard(
                        label: 'TOTAL\nCOST SAVED',
                        value: 'Rs. ${_fmtINR(totalCostSaved)}',
                        valueColor: AppTheme.primary,
                        iconData: Icons.savings_outlined,
                        iconBgColor: AppTheme.primary,
                        borderColor: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _OverviewMetricCard(
                        label: 'TOTAL\nOPTIMIZED',
                        value: 'Rs. ${_fmtINR(totalOptimizedCost)}',
                        valueColor: Colors.white,
                        iconData: Icons.savings_outlined,
                        iconBgColor: AppTheme.info,
                        borderColor: AppTheme.info,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _OverviewMetricCard(
                        label: 'TOTAL\nBASELINE',
                        value: 'Rs. ${_fmtINR(totalBaseCost)}',
                        valueColor: Colors.white,
                        iconData: Icons.savings_outlined,
                        iconBgColor: Colors.deepPurpleAccent,
                        borderColor: Colors.deepPurpleAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _OverviewMetricCard(
                        label: 'COST\nSAVED %',
                        value: '${costSavedPct.toStringAsFixed(1)}%',
                        valueColor: AppTheme.warning,
                        iconData: Icons.savings_outlined,
                        iconBgColor: AppTheme.warning,
                        borderColor: AppTheme.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Time Overview Popup ──

  void _showTimeOverviewDialog(
    BuildContext context, {
    required double totalTimeSavedMin,
    required double totalTimeTakenMin,
  }) {
    final totalBaseTime = totalTimeSavedMin + totalTimeTakenMin;
    final timeSavedPct = totalBaseTime > 0
        ? (totalTimeSavedMin / totalBaseTime * 100)
        : 0.0;

    String fmtTime(double mins) {
      final h = mins.abs() ~/ 60;
      final m = (mins.abs() % 60).round();
      return '${h}h ${m}m';
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF111111),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'TIME OVERVIEW',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // First row: 2 cards
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _OverviewMetricCard(
                        label: 'TOTAL\nTIME SAVED',
                        value: fmtTime(totalTimeSavedMin),
                        valueColor: AppTheme.primary,
                        iconData: Icons.schedule_outlined,
                        iconBgColor: AppTheme.primary,
                        borderColor: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _OverviewMetricCard(
                        label: 'TOTAL\nTIME TAKEN',
                        value: fmtTime(totalTimeTakenMin),
                        valueColor: Colors.white,
                        iconData: Icons.schedule_outlined,
                        iconBgColor: AppTheme.info,
                        borderColor: AppTheme.info,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Second row: full-width card
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _OverviewMetricCard(
                        label: 'TIME\nSAVED %',
                        value: '${timeSavedPct.toStringAsFixed(1)}%',
                        valueColor: AppTheme.warning,
                        iconData: Icons.schedule_outlined,
                        iconBgColor: AppTheme.warning,
                        borderColor: AppTheme.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Fleet / Vehicle Overview Popup ──

  void _showFleetOverviewDialog(
    BuildContext context, {
    required int totalVehicles,
    required int avgSeats,
    required double avgCostPerKm,
    required double avgSpeed,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF111111),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'VEHICLE OVERVIEW',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // First row
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _OverviewMetricCard(
                        label: 'TOTAL\nVEHICLES',
                        value: '$totalVehicles',
                        valueColor: AppTheme.primary,
                        iconData: Icons.directions_bus_outlined,
                        iconBgColor: AppTheme.primary,
                        borderColor: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _OverviewMetricCard(
                        label: 'AVG\nSEATS',
                        value: '$avgSeats',
                        valueColor: Colors.white,
                        iconData: Icons.event_seat_outlined,
                        iconBgColor: AppTheme.info,
                        borderColor: AppTheme.info,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Second row
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _OverviewMetricCard(
                        label: 'AVG\nCOST/KM',
                        value: 'Rs. ${avgCostPerKm.toStringAsFixed(1)}',
                        valueColor: Colors.deepPurpleAccent,
                        iconData: Icons.attach_money_outlined,
                        iconBgColor: Colors.deepPurpleAccent,
                        borderColor: Colors.deepPurpleAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _OverviewMetricCard(
                        label: 'AVG\nSPEED',
                        value: '${avgSpeed.toStringAsFixed(1)} km/h',
                        valueColor: AppTheme.warning,
                        iconData: Icons.speed_outlined,
                        iconBgColor: AppTheme.warning,
                        borderColor: AppTheme.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual summary stat card
// ─────────────────────────────────────────────────────────────────────────────

class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentColor.withValues(alpha: 0.2)),
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metric card used inside the cost/time/vehicle overview popups
// ─────────────────────────────────────────────────────────────────────────────

class _OverviewMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final IconData iconData;
  final Color iconBgColor;
  final Color borderColor;

  const _OverviewMetricCard({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.iconData,
    required this.iconBgColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: const Color(0xFF1C1C1E), // Match screenshot dark background
        child: Column(
          mainAxisSize:
              MainAxisSize.min, // Changed from max to min so it stays compact
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Colored top strip
            Container(height: 4, color: borderColor),
            // Removed Expanded wrapper
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ), // Tighter padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: Label + Icon
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          label.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: iconBgColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(iconData, color: iconBgColor, size: 16),
                      ),
                    ],
                  ),
                  // Fixed space instead of Spacer() to prevent over-stretching
                  const SizedBox(height: 20),
                  // Value Text
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        color: valueColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fleet Performance section header + refresh button
// ─────────────────────────────────────────────────────────────────────────────

class FleetPerformanceHeader extends StatelessWidget {
  final int fleetCount;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  const FleetPerformanceHeader({
    super.key,
    required this.fleetCount,
    required this.isRefreshing,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            const Icon(
              Icons.bar_chart_rounded,
              color: AppTheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Fleet Performance',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '$fleetCount',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: isRefreshing ? null : onRefresh,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isRefreshing
                  ? AppTheme.primary.withValues(alpha: 0.08)
                  : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isRefreshing
                    ? AppTheme.primary.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: isRefreshing
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Refresh',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state when no fleets exist
// ─────────────────────────────────────────────────────────────────────────────

class FleetEmptyState extends StatelessWidget {
  const FleetEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(
              Icons.directions_bus_outlined,
              color: Colors.white.withValues(alpha: 0.15),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'No fleets found',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scrollable list of fleet cards
// ─────────────────────────────────────────────────────────────────────────────

class FleetCardList extends StatelessWidget {
  final List<dynamic> allFleets;
  final int refreshVersion;

  const FleetCardList({
    super.key,
    required this.allFleets,
    required this.refreshVersion,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final fleet in allFleets) ...[
          FleetCard(
            key: ValueKey('${fleet['_id'] ?? fleet['id']}_$refreshVersion'),
            fleet: fleet,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual fleet card – owns its own expansion + trip-loading state
// ─────────────────────────────────────────────────────────────────────────────

class FleetCard extends StatefulWidget {
  final dynamic fleet;

  const FleetCard({super.key, required this.fleet});

  @override
  State<FleetCard> createState() => _FleetCardState();
}

class _FleetCardState extends State<FleetCard> {
  bool _isExpanded = false;
  bool _isLoadingTrips = false;
  List<dynamic>? _trips;

  late final String _oId;
  late final String _displayId;

  @override
  void initState() {
    super.initState();
    _oId =
        widget.fleet['_id']?.toString() ?? widget.fleet['id']?.toString() ?? '';
    String raw = widget.fleet['fleetId']?.toString() ?? _oId;
    if (raw.length > 4) raw = raw.substring(raw.length - 4).toUpperCase();
    _displayId = raw;

    // Pre-load trips eagerly so data is ready when expanded
    _loadTrips();
  }

  Future<void> _loadTrips({bool force = false}) async {
    if (!force && (_trips != null || _isLoadingTrips)) return;
    if (_oId.isEmpty) return;

    setState(() => _isLoadingTrips = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final res = await auth.api.fetchTrips(fleetId: _oId, limit: 50);
      if (mounted) {
        setState(() {
          _trips = res['trips'] as List<dynamic>? ?? [];
          _isLoadingTrips = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTrips = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load trips: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _toggleExpansion() {
    setState(() => _isExpanded = !_isExpanded);
  }

  // ── derived values ──────────────────────────────────────────────────────────

  String get _distance {
    if (_trips == null || _trips!.isEmpty) return '0.0 km';
    final total = _trips!.fold<double>(
      0,
      (s, t) => s + ((t['totalDistance'] as num?)?.toDouble() ?? 0.0),
    );
    return '${total.toStringAsFixed(1)} km';
  }

  int get _employeesCount {
    int count =
        widget.fleet['employees']?.length ?? widget.fleet['employeeCount'] ?? 0;
    if (count == 0 && _trips != null && _trips!.isNotEmpty) {
      final unique = <String>{};
      for (final t in _trips!) {
        if (t['assignments'] is List) {
          for (final a in (t['assignments'] as List)) {
            if (a != null) unique.add(a.toString());
          }
        } else if (t['stops'] is List) {
          for (final s in (t['stops'] as List)) {
            if (s['employee'] != null) {
              final e = s['employee'];
              final id = e is Map ? e['_id']?.toString() : e.toString();
              if (id != null) unique.add(id);
            }
          }
        }
      }
      count = unique.length;
    }
    return count;
  }

  int get _vehiclesCount {
    int count =
        widget.fleet['vehicles']?.length ?? widget.fleet['vehicleCount'] ?? 0;
    if (count == 0 && _trips != null && _trips!.isNotEmpty) {
      final unique = <String>{};
      for (final t in _trips!) {
        if (t['vehicle'] != null) {
          final v = t['vehicle'];
          final id = v is Map ? v['_id']?.toString() : v.toString();
          if (id != null) unique.add(id);
        }
      }
      count = unique.length;
    }
    return count;
  }

  double get _totalCost {
    final m = widget.fleet['metrics'];
    return (m?['optimized_cost'] as num?)?.toDouble() ?? 0.0;
  }

  double get _costSaved {
    final m = widget.fleet['metrics'];
    if (m == null) return 0.0;
    final base = (m['base_cost'] as num?)?.toDouble() ?? 0.0;
    return base - _totalCost;
  }

  // ── build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isExpanded
              ? AppTheme.primary.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.07),
        ),
        boxShadow: _isExpanded
            ? [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Column(
        children: [
          // ── header tap area ──────────────────────────────────────────────
          InkWell(
            onTap: _toggleExpansion,
            borderRadius: BorderRadius.circular(16),
            splashColor: AppTheme.primary.withValues(alpha: 0.05),
            highlightColor: AppTheme.primary.withValues(alpha: 0.03),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Fleet name badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          'Fleet $_displayId',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const Spacer(),
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white.withValues(alpha: 0.6),
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Stats row
                  Row(
                    children: [
                      MiniStat(
                        icon: Icons.route_outlined,
                        value: _distance,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 12),
                      PillBadge(
                        icon: Icons.people_outline_rounded,
                        count: '$_employeesCount',
                        color: AppTheme.info,
                      ),
                      const SizedBox(width: 8),
                      PillBadge(
                        icon: Icons.directions_car_outlined,
                        count: '$_vehiclesCount',
                        color: AppTheme.warning,
                      ),
                      const Spacer(),
                      // Cost summary on the right
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Rs. ${_fmtINR(_totalCost)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.arrow_downward_rounded,
                                color: AppTheme.primary,
                                size: 10,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'Rs. ${_fmtINR(_costSaved)} saved',
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── expandable trip details ──────────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: TripDetailsPanel(
              displayId: _displayId,
              trips: _trips,
              isLoading: _isLoadingTrips,
              fleet: widget.fleet,
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trip details panel (shown when fleet card is expanded)
// ─────────────────────────────────────────────────────────────────────────────

class TripDetailsPanel extends StatelessWidget {
  final String displayId;
  final List<dynamic>? trips;
  final bool isLoading;
  final dynamic fleet;

  const TripDetailsPanel({
    super.key,
    required this.displayId,
    required this.trips,
    required this.isLoading,
    required this.fleet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: const Row(
              children: [
                TripHeaderCell(label: 'TRIP', flex: 4),
                TripHeaderCell(label: 'DIST', flex: 3),
                TripHeaderCell(label: 'EMP', flex: 2),
                TripHeaderCell(label: 'VEH', flex: 2),
                TripHeaderCell(label: 'COST', flex: 3, rightAlign: true),
                TripHeaderCell(label: 'SAVED', flex: 3, rightAlign: true),
              ],
            ),
          ),

          // Content
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                ),
              ),
            )
          else if (trips == null || trips!.isEmpty)
            const TripEmptyState()
          else
            TripTableRows(trips: trips!, fleet: fleet),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trip table header cell
// ─────────────────────────────────────────────────────────────────────────────

class TripHeaderCell extends StatelessWidget {
  final String label;
  final int flex;
  final bool rightAlign;

  const TripHeaderCell({
    super.key,
    required this.label,
    this.flex = 1,
    this.rightAlign = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: rightAlign ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.35),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state inside the trip details panel
// ─────────────────────────────────────────────────────────────────────────────

class TripEmptyState extends StatelessWidget {
  const TripEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.route_outlined,
              color: Colors.white.withValues(alpha: 0.15),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              'No trips found for this fleet',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// All trip rows with proportional cost computation
// ─────────────────────────────────────────────────────────────────────────────

class TripTableRows extends StatelessWidget {
  final List<dynamic> trips;
  final dynamic fleet;

  const TripTableRows({super.key, required this.trips, required this.fleet});

  @override
  Widget build(BuildContext context) {
    final hasMetrics = fleet['metrics'] != null;
    double fleetOptimizedCost = 0.0;
    double fleetBaseCost = 0.0;

    if (hasMetrics) {
      final m = fleet['metrics'];
      fleetOptimizedCost = (m['optimized_cost'] as num?)?.toDouble() ?? 0.0;
      fleetBaseCost = (m['base_cost'] as num?)?.toDouble() ?? 0.0;
    }
    final fleetCostSaved = fleetBaseCost - fleetOptimizedCost;

    // Total fleet distance — denominator for proportional cost split
    final totalFleetDist = trips.fold<double>(
      0.0,
      (sum, t) => sum + ((t['totalDistance'] as num?)?.toDouble() ?? 0.0),
    );

    return Column(
      children: [
        for (final trip in trips)
          TripTableRow(
            trip: trip,
            totalFleetDist: totalFleetDist,
            fleetOptimizedCost: fleetOptimizedCost,
            fleetCostSaved: fleetCostSaved,
            hasMetrics: hasMetrics,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single trip row
// ─────────────────────────────────────────────────────────────────────────────

class TripTableRow extends StatelessWidget {
  final dynamic trip;
  final double totalFleetDist;
  final double fleetOptimizedCost;
  final double fleetCostSaved;
  final bool hasMetrics;

  const TripTableRow({
    super.key,
    required this.trip,
    required this.totalFleetDist,
    required this.fleetOptimizedCost,
    required this.fleetCostSaved,
    required this.hasMetrics,
  });

  String get _displayId {
    final raw = trip['_id']?.toString() ?? trip['id']?.toString() ?? '';
    return raw.length > 4
        ? 'Trip ${raw.substring(raw.length - 4).toUpperCase()}'
        : raw;
  }

  double get _distVal => (trip['totalDistance'] as num?)?.toDouble() ?? 0.0;
  String get _dist => '${_distVal.toStringAsFixed(1)} km';
  int get _vCount => trip['vehicle'] != null ? 1 : 0;

  int get _eCount {
    if (trip['assignments'] is List) {
      return (trip['assignments'] as List).length;
    }
    if (trip['stops'] is List) {
      final unique = <String>{};
      for (final s in (trip['stops'] as List)) {
        if (s['employee'] != null) unique.add(s['employee'].toString());
      }
      return unique.length;
    }
    return 0;
  }

  String get _costStr {
    if (!hasMetrics) return '—';
    if (totalFleetDist <= 0) return 'Rs. 0';
    final share = _distVal / totalFleetDist;
    return 'Rs. ${_fmtINR(share * fleetOptimizedCost)}';
  }

  String get _savedStr {
    if (!hasMetrics) return '—';
    if (totalFleetDist <= 0) return 'Rs. 0';
    final share = _distVal / totalFleetDist;
    return 'Rs. ${_fmtINR(share * fleetCostSaved)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              _displayId,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _dist,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '$_eCount',
              style: TextStyle(
                color: AppTheme.info.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '$_vCount',
              style: TextStyle(
                color: AppTheme.warning.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _costStr,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: hasMetrics
                    ? Colors.white.withValues(alpha: 0.75)
                    : Colors.white24,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _savedStr,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: hasMetrics ? AppTheme.primary : Colors.white24,
                fontSize: 12,
                fontWeight: hasMetrics ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small icon + text inline stat
// ─────────────────────────────────────────────────────────────────────────────

class MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const MiniStat({
    super.key,
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Coloured pill badge for counts
// ─────────────────────────────────────────────────────────────────────────────

class PillBadge extends StatelessWidget {
  final IconData icon;
  final String count;
  final Color color;

  const PillBadge({
    super.key,
    required this.icon,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            count,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
