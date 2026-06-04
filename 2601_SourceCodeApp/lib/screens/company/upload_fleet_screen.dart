import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';

class UploadFleetScreen extends StatefulWidget {
  const UploadFleetScreen({super.key});

  @override
  State<UploadFleetScreen> createState() => _UploadFleetScreenState();
}

class _UploadFleetScreenState extends State<UploadFleetScreen> {
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  String? _error;
  Map<String, dynamic>? _result;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
        _error = null;
        _result = null;
      });
    }
  }

  Future<void> _upload() async {
    if (_selectedFile == null || _selectedFile!.path == null) {
      setState(() => _error = "Please select a file first.");
      return;
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.userId == null) return;

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final data = await auth.api.uploadFleetFile(
        _selectedFile!.path!,
        auth.userId!,
      );
      if (mounted) {
        setState(() {
          _result = data;
          _isUploading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(title: const Text("Create Fleet")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(w * 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            Container(
              padding: EdgeInsets.all(w * 0.04),
              decoration: BoxDecoration(
                color: AppTheme.info.withAlpha(15), // 0.06
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.info.withAlpha(38)), // 0.15
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppTheme.info,
                        size: w * 0.05,
                      ),
                      SizedBox(width: w * 0.02),
                      Text(
                        "CSV Format Guide",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: w * 0.04,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: w * 0.02),
                  Text(
                    "Your CSV should include columns: Fleet ID, Office Location, Fleet Size",
                    style: TextStyle(
                      fontSize: w * 0.035,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: w * 0.06),

            // File Picker
            InkWell(
              onTap: _pickFile,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: EdgeInsets.all(w * 0.08),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedFile != null
                        ? AppTheme.success
                        : AppTheme.divider,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _selectedFile != null
                          ? Icons.check_circle
                          : Icons.cloud_upload_outlined,
                      size: w * 0.12,
                      color: _selectedFile != null
                          ? AppTheme.success
                          : AppTheme.textSecondary,
                    ),
                    SizedBox(height: w * 0.03),
                    Text(
                      _selectedFile != null
                          ? _selectedFile!.name
                          : "Tap to select CSV file (.csv)",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: w * 0.035,
                        color: _selectedFile != null
                            ? AppTheme.success
                            : AppTheme.textSecondary,
                      ),
                    ),
                    if (_selectedFile != null) ...[
                      SizedBox(height: w * 0.01),
                      Text(
                        "${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB",
                        style: TextStyle(
                          fontSize: w * 0.03,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: w * 0.06),

            // Error
            if (_error != null)
              Container(
                padding: EdgeInsets.all(w * 0.03),
                margin: EdgeInsets.only(bottom: w * 0.04),
                decoration: BoxDecoration(
                  color: AppTheme.errorLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: AppTheme.error, size: w * 0.045),
                    SizedBox(width: w * 0.02),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: AppTheme.error,
                          fontSize: w * 0.035,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Upload Button
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _upload,
              icon: _isUploading
                  ? SizedBox(
                      width: w * 0.045,
                      height: w * 0.045,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.textWhite,
                      ),
                    )
                  : const Icon(Icons.upload),
              label: Text(_isUploading ? "Processing..." : "Create Fleet"),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: w * 0.04),
              ),
            ),
            SizedBox(height: w * 0.06),

            // Success Result
            if (_result != null) _buildResultCard(w),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(double width) {
    final fleet = _result!['fleet'];
    final fleetId = fleet?['_id'] ?? fleet?['id'];

    return Container(
      padding: EdgeInsets.all(width * 0.04),
      decoration: BoxDecoration(
        color: AppTheme.successLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppTheme.success),
              SizedBox(width: width * 0.02),
              const Text(
                "Fleet Created Successfully!",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
          Divider(height: width * 0.06, color: Colors.green.shade200),
          _resultRow("Fleet ID", fleet?['fleetId'] ?? 'N/A'),
          _resultRow("Vehicles", "${_result!['vehicleCount'] ?? 0}"),
          _resultRow("Employees", "${_result!['employeeCount'] ?? 0}"),
          _resultRow("Trips", "${_result!['tripCount'] ?? 0}"),
          SizedBox(height: width * 0.03),
          if (fleetId != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.push('/fleet/$fleetId'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.success,
                  side: const BorderSide(color: AppTheme.success),
                ),
                child: const Text("View Fleet Details"),
              ),
            ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textPrimary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
