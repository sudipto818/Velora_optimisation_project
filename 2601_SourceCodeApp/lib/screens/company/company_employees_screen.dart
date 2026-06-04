import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';

class CompanyEmployeesScreen extends StatefulWidget {
  const CompanyEmployeesScreen({super.key});

  @override
  State<CompanyEmployeesScreen> createState() => _CompanyEmployeesScreenState();
}

class _CompanyEmployeesScreenState extends State<CompanyEmployeesScreen> {
  List<dynamic> _employees = [];
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees({int page = 1}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.userId == null) return;

    try {
      final data = await auth.api.fetchCompanyEmployees(
        auth.userId!,
        page: page,
        limit: 20,
      );
      if (mounted) {
        setState(() {
          _employees = data['employees'] ?? [];
          _currentPage = data['currentPage'] ?? 1;
          _totalPages = data['totalPages'] ?? 1;
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

  // ─── Export Dialog ───────────────────────────────────────────

  void _showExportDialog() {
    // Field selections — local to the dialog
    final fields = <String, bool>{
      'employeeId': true,
      'name': true,
      'email': true,
      'rideStatus': true,
    };

    final fieldLabels = <String, String>{
      'employeeId': 'EMPLOYEE ID',
      'name': 'NAME',
      'email': 'EMAIL',
      'rideStatus': 'RIDE STATUS',
    };

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppTheme.border),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 40,
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header: green bar + title ──
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Report Configuration',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Field chips (scrollable) ──
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: fields.keys.map((key) {
                          final selected = fields[key]!;
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  fields[key] = !fields[key]!;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppTheme.primary.withAlpha(20)
                                      : AppTheme.surfaceHighlight,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selected
                                        ? AppTheme.primary
                                        : AppTheme.border,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? AppTheme.primary
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(
                                          color: selected
                                              ? AppTheme.primary
                                              : AppTheme.textSecondary,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: selected
                                          ? const Icon(
                                              Icons.check,
                                              size: 14,
                                              color: Colors.black,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      fieldLabels[key]!,
                                      style: TextStyle(
                                        color: selected
                                            ? AppTheme.primary
                                            : AppTheme.textSecondary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Buttons at the bottom ──
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _exportPdf(fields),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textPrimary,
                              side: BorderSide(color: AppTheme.border),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Download PDF',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _exportCsv(fields),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textPrimary,
                              side: BorderSide(color: AppTheme.border),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Export CSV',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── PDF Export ──────────────────────────────────────────────

  Future<void> _exportPdf(Map<String, bool> fields) async {
    Navigator.of(context).pop(); // close dialog

    final selectedKeys = fields.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (selectedKeys.isEmpty) {
      _showSnackBar('Please select at least one field');
      return;
    }

    _showSnackBar('Preparing PDF...');

    final fieldLabels = <String, String>{
      'employeeId': 'Employee ID',
      'name': 'Name',
      'email': 'Email',
      'rideStatus': 'Ride Status',
    };

    try {
      final pdf = pw.Document();

      final headers = selectedKeys.map((k) => fieldLabels[k]!).toList();
      final dataRows = _employees.map((emp) {
        return selectedKeys.map((k) => (emp[k] ?? '').toString()).toList();
      }).toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Employee Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: dataRows,
              border: pw.TableBorder.all(color: PdfColors.grey),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(8),
            ),
          ],
        ),
      );

      final Uint8List bytes = await pdf.save();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Employee Report',
        fileName:
            'Employees_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );

      if (outputFile != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF successfully downloaded!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export PDF: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  // ─── CSV Export ─────────────────────────────────────────────

  Future<void> _exportCsv(Map<String, bool> fields) async {
    Navigator.of(context).pop(); // close dialog

    final selectedKeys = fields.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (selectedKeys.isEmpty) {
      _showSnackBar('Please select at least one field');
      return;
    }

    _showSnackBar('Preparing CSV...');

    final fieldLabels = <String, String>{
      'employeeId': 'Employee ID',
      'name': 'Name',
      'email': 'Email',
      'rideStatus': 'Ride Status',
    };

    try {
      final buffer = StringBuffer();

      // Header row
      buffer.writeln(selectedKeys.map((k) => fieldLabels[k]!).join(','));

      // Data rows
      for (final emp in _employees) {
        final row = selectedKeys
            .map((k) {
              String val = (emp[k] ?? '').toString().replaceAll('"', '""');
              return '"$val"';
            })
            .join(',');
        buffer.writeln(row);
      }

      final Uint8List bytes = Uint8List.fromList(
        utf8.encode(buffer.toString()),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Employee Data',
        fileName: 'Employees_Data_${DateTime.now().millisecondsSinceEpoch}.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: bytes,
      );

      if (outputFile != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV successfully downloaded!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export CSV: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showSnackBar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // ─── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Employees"),
        actions: [
          IconButton(
            onPressed: _showExportDialog,
            tooltip: 'Export',
            icon: const Icon(Icons.file_download_outlined),
          ),
        ],
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
                    onPressed: _loadEmployees,
                    child: const Text("Retry"),
                  ),
                ],
              ),
            )
          : _employees.isEmpty
          ? const Center(
              child: Text(
                "No employees found.",
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _loadEmployees(page: 1),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.all(w * 0.04),
                      itemCount: _employees.length,
                      itemBuilder: (context, index) {
                        final emp = _employees[index];
                        return _EmployeeCard(
                          name: emp['name'] ?? 'Unknown',
                          email: emp['email'] ?? '',
                          employeeId: emp['employeeId'] ?? '',
                          rideStatus: emp['rideStatus'] ?? 'pending',
                          width: w,
                        );
                      },
                    ),
                  ),
                  if (_totalPages > 1)
                    Padding(
                      padding: EdgeInsets.all(w * 0.03),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: _currentPage > 1
                                ? () => _loadEmployees(page: _currentPage - 1)
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text("Page $_currentPage of $_totalPages"),
                          IconButton(
                            onPressed: _currentPage < _totalPages
                                ? () => _loadEmployees(page: _currentPage + 1)
                                : null,
                            icon: const Icon(Icons.chevron_right),
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

class _EmployeeCard extends StatelessWidget {
  final String name;
  final String email;
  final String employeeId;
  final String rideStatus;
  final double width;

  const _EmployeeCard({
    required this.name,
    required this.email,
    required this.employeeId,
    required this.rideStatus,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = AppTheme.getStatusColor(rideStatus);

    return Card(
      margin: EdgeInsets.only(bottom: width * 0.025),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryLight,
          radius: width * 0.05,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
              fontSize: width * 0.04,
            ),
          ),
        ),
        title: Text(
          name,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: width * 0.04),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(email, style: TextStyle(fontSize: width * 0.03)),
            if (employeeId.isNotEmpty)
              Text(
                "ID: $employeeId",
                style: TextStyle(
                  fontSize: width * 0.028,
                  color: AppTheme.textSecondary,
                ),
              ),
          ],
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(
            horizontal: width * 0.025,
            vertical: width * 0.01,
          ),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(26), // 0.1
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            rideStatus,
            style: TextStyle(
              color: statusColor,
              fontSize: width * 0.028,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
