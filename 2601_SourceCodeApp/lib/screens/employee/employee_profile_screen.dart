import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';

class EmployeeProfileScreen extends StatefulWidget {
  const EmployeeProfileScreen({super.key});

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  Map<String, dynamic>? _employee;
  Map<String, dynamic>? _preferences;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.userId == null) return;

    try {
      final data = await auth.api.fetchEmployeeProfile(auth.userId!);
      if (mounted) {
        setState(() {
          _employee = data['employee'];
          _preferences = data['preferences'];
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

  Future<void> _updateProfile(String name, String phone) async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.api.updateEmployeeDetails(auth.userId!, {
        'name': name.trim(),
        'phone': phone.trim(),
      });
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      _loadProfile();
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Update failed: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _showEditProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _EditProfileDialog(
          initialName: _employee?['name'] ?? '',
          initialPhone: _employee?['phone'] ?? '',
          onSave: (name, phone) {
            _updateProfile(name, phone);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Profile',
            onPressed: () => _showEditProfileDialog(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          auth.logout();
        },
        backgroundColor: Colors.red,
        icon: const Icon(Icons.logout, color: Colors.white),
        label: const Text(
          "Logout",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
                    onPressed: _loadProfile,
                    child: const Text("Retry"),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(w * 0.04),
                child: Column(
                  children: [
                    // Avatar + Name
                    CircleAvatar(
                      radius: w * 0.1,
                      backgroundColor: AppTheme.primaryLight,
                      child: Text(
                        (_employee?['name'] ?? '?')[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: w * 0.08,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    SizedBox(height: w * 0.03),
                    Text(
                      _employee?['name'] ?? 'Unknown',
                      style: TextStyle(
                        fontSize: w * 0.055,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _employee?['email'] ?? '',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    if (_employee?['phone'] != null &&
                        _employee!['phone'].toString().isNotEmpty)
                      Text(
                        _employee?['phone'] ?? '',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    SizedBox(height: w * 0.06),

                    // Details Card
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(w * 0.04),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Details",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: w * 0.04,
                              ),
                            ),
                            Divider(height: w * 0.05, color: AppTheme.divider),
                            _ProfileRow(
                              label: "Employee ID",
                              value: _employee?['employeeId'] ?? 'N/A',
                              width: w,
                            ),
                            _ProfileRow(
                              label: "Ride Status",
                              value: _employee?['rideStatus'] ?? 'N/A',
                              width: w,
                            ),
                            if (_employee?['company'] != null)
                              _ProfileRow(
                                label: "Company",
                                value: _employee!['company'] is Map
                                    ? _employee!['company']['name'] ?? 'N/A'
                                    : 'N/A',
                                width: w,
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: w * 0.04),

                    // Preferences Card
                    if (_preferences != null)
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(w * 0.04),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Ride Preferences",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: w * 0.04,
                                ),
                              ),
                              Divider(
                                height: w * 0.05,
                                color: AppTheme.divider,
                              ),
                              _ProfileRow(
                                label: "Sharing",
                                value:
                                    _preferences!['sharingPreference'] ?? 'N/A',
                                width: w,
                              ),
                              _ProfileRow(
                                label: "Vehicle Pref",
                                value:
                                    _preferences!['vehiclePreference'] ?? 'N/A',
                                width: w,
                              ),
                              if (_preferences!['timeWindow'] != null)
                                _ProfileRow(
                                  label: "Time Window",
                                  value:
                                      "${_preferences!['timeWindow']['startTime'] ?? ''} - ${_preferences!['timeWindow']['endTime'] ?? ''}",
                                  width: w,
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;
  final double width;

  const _ProfileRow({
    required this.label,
    required this.value,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: width * 0.015),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: width * 0.3,
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: width * 0.035,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: width * 0.035,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  final String initialName;
  final String initialPhone;
  final void Function(String name, String phone) onSave;

  const _EditProfileDialog({
    required this.initialName,
    required this.initialPhone,
    required this.onSave,
  });

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Edit Profile"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: "Name"),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: "Phone"),
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onSave(_nameController.text, _phoneController.text);
          },
          child: const Text("Save"),
        ),
      ],
    );
  }
}
