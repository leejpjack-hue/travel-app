import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'token_storage.dart';
import 'models/trip.dart';

class TripCreateScreen extends StatefulWidget {
  final void Function(Trip trip)? onTripCreated;

  const TripCreateScreen({super.key, this.onTripCreated});

  @override
  State<TripCreateScreen> createState() => _TripCreateScreenState();
}

class _TripCreateScreenState extends State<TripCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _destinationController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isLoading = false;
  String? _authToken;

  @override
  void initState() {
    super.initState();
    _loadAuthToken();
  }

  Future<void> _loadAuthToken() async {
    // In a real app, load from secure storage
    final token = await _getStoredToken();
    setState(() {
      _authToken = token;
    });
  }

  Future<String?> _getStoredToken() async {
    return await TokenStorage.getToken();
  }

  Future<void> _createTrip() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse('/api/trips');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
        },
        body: json.encode({
          'name': _nameController.text,
          'destination': _destinationController.text,
          'start_date': _startDateController.text,
          'end_date': _endDateController.text,
          'description': _descriptionController.text,
        }),
      );

      if (response.statusCode == 201) {
        final tripData = json.decode(response.body)['trip'];
        if (tripData != null && widget.onTripCreated != null) {
          widget.onTripCreated!(Trip.fromJson(tripData));
        }
        _showSuccessDialog('行程已成功創建！');
        _formKey.currentState?.reset();
      } else {
        final error = json.decode(response.body)['error'] ?? '創建行程失敗';
        _showErrorDialog('錯誤: $error');
      }
    } catch (e) {
      _showErrorDialog('網路錯誤: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('成功'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('錯誤'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('創建新行程', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4ECDC4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App name and branding
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ECDC4).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.flight_takeoff,
                            size: 60,
                            color: Color(0xFF4ECDC4),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'ZenVoyage',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4ECDC4),
                            ),
                          ),
                          Text(
                            '全方位旅遊行程規劃',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),

              // Trip name
              _buildTextField(
                controller: _nameController,
                label: '行程名稱',
                hint: '例如：東京春節之旅',
                validator: (value) => value?.isEmpty ?? true ? '請輸入行程名稱' : null,
              ),

              const SizedBox(height: 16),

              // Destination
              _buildTextField(
                controller: _destinationController,
                label: '目的地',
                hint: '例如：日本東京',
                validator: (value) => value?.isEmpty ?? true ? '請輸入目的地' : null,
              ),

              const SizedBox(height: 16),

              // Date range
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _startDateController,
                      label: '開始日期',
                      hint: '2024-02-10',
                      readOnly: true,
                      onTap: () => _selectDate(_startDateController),
                      validator: (value) => value?.isEmpty ?? true ? '請選擇開始日期' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _endDateController,
                      label: '結束日期',
                      hint: '2024-02-15',
                      readOnly: true,
                      onTap: () => _selectDate(_endDateController),
                      validator: (value) => value?.isEmpty ?? true ? '請選擇結束日期' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Description
              _buildTextField(
                controller: _descriptionController,
                label: '行程描述',
                hint: '描述您的行程計劃...',
                maxLines: 3,
                keyboardType: TextInputType.multiline,
              ),

              const SizedBox(height: 30),

              // Create button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createTrip,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECDC4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 16),
                            Text('創建中...'),
                          ],
                        )
                      : const Text(
                          '創建行程',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3436),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.grey.shade300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF4ECDC4),
                width: 2,
              ),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          validator: validator,
          readOnly: readOnly,
          onTap: onTap,
          maxLines: maxLines,
          keyboardType: keyboardType,
        ),
      ],
    );
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF4ECDC4),
              onPrimary: Colors.white,
              onSurface: const Color(0xFF2D3436),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      controller.text = picked.toIso8601String().substring(0, 10);
    }
  }
}