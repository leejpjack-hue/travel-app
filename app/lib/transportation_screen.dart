import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TransportationPlanningScreen extends StatefulWidget {
  final String tripId;

  const TransportationPlanningScreen({Key? key, required this.tripId}) : super(key: key);

  @override
  _TransportationPlanningScreenState createState() => _TransportationPlanningScreenState();
}

class _TransportationPlanningScreenState extends State<TransportationPlanningScreen> {
  List<Map<String, dynamic>> transportationModes = [];
  List<Map<String, dynamic>> optimizations = [];
  bool isLoading = true;
  String? selectedMode;
  TextEditingController modeNameController = TextEditingController();
  TextEditingController modeTypeController = TextEditingController();
  TextEditingController costController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTransportationModes();
    _loadOptimizations();
  }

  Future<void> _loadTransportationModes() async {
    try {
      final response = await http.get(
        Uri.parse('/api/trips/${widget.tripId}/transportation-modes'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          transportationModes = List<Map<String, dynamic>>.from(data['transportation_modes']);
          isLoading = false;
        });
      } else {
        _showError('Failed to load transportation modes');
      }
    } catch (e) {
      _showError('Error loading transportation modes: $e');
    }
  }

  Future<void> _loadOptimizations() async {
    try {
      final response = await http.get(
        Uri.parse('/api/trips/${widget.tripId}/route-optimizations'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          optimizations = List<Map<String, dynamic>>.from(data['route_optimizations']);
        });
      }
    } catch (e) {
      // Optimization history might be empty
    }
  }

  Future<void> _addTransportationMode() async {
    if (modeNameController.text.isEmpty || modeTypeController.text.isEmpty) {
      _showError('Name and type are required');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('/api/trips/${widget.tripId}/transportation-modes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': modeNameController.text,
          'type': modeTypeController.text,
          'cost_per_km': int.tryParse(costController.text) ?? 0,
          'description': descriptionController.text,
          'icon': _getModeIcon(modeTypeController.text),
        }),
      );

      if (response.statusCode == 201) {
        _showSuccess('Transportation mode added successfully');
        modeNameController.clear();
        modeTypeController.clear();
        costController.clear();
        descriptionController.clear();
        _loadTransportationModes();
      } else {
        _showError('Failed to add transportation mode');
      }
    } catch (e) {
      _showError('Error adding transportation mode: $e');
    }
  }

  Future<void> _optimizeRoute() async {
    try {
      setState(() {
        isLoading = true;
      });

      final response = await http.post(
        Uri.parse('/api/trips/${widget.tripId}/route-optimization'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'algorithm': 'nearest_neighbor',
          'optimize_for': 'time',
          'exclude_locked': true,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        _showSuccess('Route optimized successfully');
        _loadOptimizations();
      } else {
        _showError('Failed to optimize route');
      }
    } catch (e) {
      _showError('Error optimizing route: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  String _getModeIcon(String type) {
    switch (type) {
      case 'walking':
        return '🚶';
      case 'public':
        return '🚌';
      case 'taxi':
        return '🚕';
      case 'bike':
        return '🚲';
      case 'train':
        return '🚆';
      case 'bus':
        return '🚌';
      case 'car':
        return '🚗';
      case 'ferry':
        return '⛴️';
      default:
        return '🚦';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('交通規劃'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Transportation Modes Section
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.directions_car, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                '交通方式',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Spacer(),
                              ElevatedButton.icon(
                                icon: Icon(Icons.add),
                                label: Text('新增方式'),
                                onPressed: () => _showAddModeDialog(),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          if (transportationModes.isEmpty)
                            Text('沒有交通方式，請新增')
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: transportationModes.length,
                              itemBuilder: (context, index) {
                                final mode = transportationModes[index];
                                return Card(
                                  margin: EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: Text(mode['icon'] ?? '🚦'),
                                    title: Text(mode['name'] ?? ''),
                                    subtitle: Text('${mode['type'] ?? ''} - ¥${mode['cost_per_km'] ?? 0}/km'),
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          // TODO: Implement edit functionality
                                        } else if (value == 'delete') {
                                          // TODO: Implement delete functionality
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem(value: 'edit', child: Text('編輯')),
                                        PopupMenuItem(value: 'delete', child: Text('刪除')),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Route Optimization Section
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.route, color: Colors.green),
                              SizedBox(width: 8),
                              Text(
                                '路線最佳化',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Spacer(),
                              ElevatedButton.icon(
                                icon: Icon(Icons.optimize),
                                label: Text('最佳化路線'),
                                onPressed: _optimizeRoute,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          if (optimizations.isEmpty)
                            Text('尚未進行路線最佳化')
                          else
                            Column(
                              children: optimizations.map((opt) {
                                return Card(
                                  margin: EdgeInsets.only(bottom: 8),
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              '${opt['name'] ?? ''}',
                                              style: TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            Spacer(),
                                            Text(
                                              '${opt['total_duration_minutes'] ?? 0}分鐘',
                                              style: TextStyle(color: Colors.blue),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          '總距離: ${(opt['total_distance_meters'] ?? 0) / 1000}公里',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                        Text(
                                          '總費用: ¥${opt['total_cost'] ?? 0}',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                        if (opt['segments'] != null)
                                          Text(
                                            '路段數: ${opt['segments'].length}',
                                            style: TextStyle(color: Colors.grey),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showAddModeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('新增交通方式'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: modeNameController,
                decoration: InputDecoration(labelText: '方式名稱'),
              ),
              TextField(
                controller: modeTypeController,
                decoration: InputDecoration(labelText: '方式類型 (walking/public/taxi/bike)'),
              ),
              TextField(
                controller: costController,
                decoration: InputDecoration(labelText: '每公里費用 (¥)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(labelText: '描述'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              _addTransportationMode();
              Navigator.pop(context);
            },
            child: Text('新增'),
          ),
        ],
      ),
    );
  }
}