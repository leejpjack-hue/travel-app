import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../api_service.dart';

class PdfExportScreen extends StatefulWidget {
  final Trip trip;

  const PdfExportScreen({super.key, required this.trip});

  @override
  State<PdfExportScreen> createState() => _PdfExportScreenState();
}

class _PdfExportScreenState extends State<PdfExportScreen> {
  bool _isExporting = false;
  double _exportProgress = 0.0;
  String _exportStatus = '';
  bool _exportSuccess = false;
  String _exportError = '';

  final Map<String, bool> _selectedSections = {
    'overview': true,
    'itinerary': true,
    'destinations': true,
    'bookings': true,
    'transportation': true,
    'expenses': true,
    'companions': true,
    'emergency': true,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Travel Handbook'),
        backgroundColor: const Color(0xFF4ECDC4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTripHeader(),
            const SizedBox(height: 20),
            _buildSectionSelector(),
            const SizedBox(height: 20),
            if (_exportError.isNotEmpty) _buildErrorCard(),
            if (_exportSuccess) _buildSuccessCard(),
            if (_isExporting) _buildProgressCard(),
            const SizedBox(height: 16),
            _buildExportButton(),
            const SizedBox(height: 16),
            _buildInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildTripHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4ECDC4), Color(0xFF44A3AA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4ECDC4).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'ZenVoyage',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.picture_as_pdf,
                color: Colors.white.withOpacity(0.8),
                size: 28,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.trip.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.trip.destination} | ${_formatDateRange(widget.trip.startDate, widget.trip.endDate)}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'PDF Content Sections',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3436),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _toggleAllSections,
              child: Text(
                _allSelected ? 'Deselect All' : 'Select All',
                style: const TextStyle(color: Color(0xFF4ECDC4)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._selectedSections.keys.map((key) => _buildSectionCheckbox(key)),
      ],
    );
  }

  Widget _buildSectionCheckbox(String key) {
    final sectionInfo = {
      'overview': {'icon': Icons.list_alt, 'title': 'Trip Overview', 'desc': 'Trip name, dates, status, preferences'},
      'itinerary': {'icon': Icons.schedule, 'title': 'Daily Itinerary', 'desc': 'Timeline items with times and locations'},
      'destinations': {'icon': Icons.place, 'title': 'Destinations & Map', 'desc': 'All locations with coordinates'},
      'bookings': {'icon': Icons.confirmation_number, 'title': 'Bookings & Tickets', 'desc': 'Flights, hotels, activities, digital tickets'},
      'transportation': {'icon': Icons.directions_transit, 'title': 'Transportation', 'desc': 'Transport modes and route segments'},
      'expenses': {'icon': Icons.account_balance_wallet, 'title': 'Expense Summary', 'desc': 'Category breakdown and recent expenses'},
      'companions': {'icon': Icons.people, 'title': 'Travel Companions', 'desc': 'Collaborator information'},
      'emergency': {'icon': Icons.emergency, 'title': 'Emergency Information', 'desc': 'Emergency numbers and contacts'},
    };

    final info = sectionInfo[key]!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: _selectedSections[key]! ? const Color(0xFF4ECDC4) : Colors.grey[300]!,
            width: _selectedSections[key]! ? 1.5 : 0.5,
          ),
        ),
        child: InkWell(
          onTap: () => _toggleSection(key),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(info['icon'] as IconData,
                    size: 20,
                    color: _selectedSections[key]! ? const Color(0xFF4ECDC4) : Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info['title'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _selectedSections[key]! ? const Color(0xFF2D3436) : Colors.grey,
                        ),
                      ),
                      Text(
                        info['desc'] as String,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Checkbox(
                  value: _selectedSections[key],
                  onChanged: (_) => _toggleSection(key),
                  activeColor: const Color(0xFF4ECDC4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _exportError,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _exportError = ''),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'PDF generated successfully! Download should start automatically.',
              style: TextStyle(color: Colors.green, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18, color: Colors.green),
            onPressed: () => setState(() => _exportSuccess = false),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Export again',
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF4ECDC4).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4ECDC4).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Color(0xFF4ECDC4),
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _exportStatus,
                style: const TextStyle(
                  color: Color(0xFF2D3436),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _exportProgress,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4ECDC4)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton() {
    final selectedCount = _selectedSections.values.where((v) => v).length;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isExporting || selectedCount == 0 ? null : _exportPdf,
        icon: _isExporting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.picture_as_pdf),
        label: Text(
          _isExporting
              ? 'Generating...'
              : 'Generate PDF Handbook ($selectedCount sections)',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4ECDC4),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[500],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'About PDF Export',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'The generated PDF includes a beautiful cover page, table of contents, and all selected sections. '
            'It collects data from your itinerary, destinations, bookings, transportation, expenses, and more. '
            'The PDF is generated server-side and will be downloaded automatically.',
            style: TextStyle(
              color: Colors.grey[600],
              height: 1.5,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  bool get _allSelected => _selectedSections.values.every((v) => v);

  void _toggleSection(String key) {
    setState(() {
      _selectedSections[key] = !_selectedSections[key]!;
    });
  }

  void _toggleAllSections() {
    final newState = !_allSelected;
    setState(() {
      for (final key in _selectedSections.keys) {
        _selectedSections[key] = newState;
      }
    });
  }

  String _formatDateRange(DateTime? start, DateTime? end) {
    if (start == null || end == null) return 'Dates not set';
    final formatter = DateFormat('yyyy-MM-dd');
    return '${formatter.format(start)} ~ ${formatter.format(end)}';
  }

  Future<void> _exportPdf() async {
    setState(() {
      _isExporting = true;
      _exportSuccess = false;
      _exportError = '';
      _exportProgress = 0.1;
      _exportStatus = 'Preparing data...';
    });

    try {
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() {
        _exportProgress = 0.3;
        _exportStatus = 'Collecting trip data...';
      });

      final apiService = ApiService();
      final response = await apiService.exportPdf(widget.trip.id);

      setState(() {
        _exportProgress = 0.7;
        _exportStatus = 'Generating PDF...';
      });

      if (response.statusCode == 200) {
        setState(() {
          _exportProgress = 1.0;
          _exportStatus = 'PDF ready! Starting download...';
        });

        _downloadPdf(response.bodyBytes);

        await Future.delayed(const Duration(milliseconds: 500));
        setState(() {
          _isExporting = false;
          _exportSuccess = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF travel handbook generated successfully!'),
              backgroundColor: Color(0xFF4ECDC4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        String errorMsg = 'PDF generation failed';
        try {
          final errorBody = json.decode(response.body);
          errorMsg = errorBody['error'] ?? errorMsg;
        } catch {}
        setState(() {
          _isExporting = false;
          _exportError = errorMsg;
        });
      }
    } catch (e) {
      setState(() {
        _isExporting = false;
        _exportError = 'Connection error: $e';
      });
    }
  }

  void _downloadPdf(List<int> pdfBytes) {
    try {
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'ZenVoyage-${widget.trip.name}-Handbook.pdf')
        ..click();
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      _showDownloadDialog();
    }
  }

  void _showDownloadDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PDF Ready'),
        content: const Text('Your PDF travel handbook has been generated. '
            'The download should start automatically. '
            'If not, please check your browser downloads.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
