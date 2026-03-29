import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class POIScreen extends StatefulWidget {
  final String tripId;
  
  const POIScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<POIScreen> createState() => _POIScreenState();
}

class _POIScreenState extends State<POIScreen> {
  List<Map<String, dynamic>> customPins = [];
  List<Map<String, dynamic>> poiTags = [];
  List<Map<String, dynamic>> poiReviews = [];
  List<Map<String, dynamic>> poiNames = [];
  List<Map<String, dynamic>> seasonalAlerts = [];
  
  bool isLoading = true;
  int currentTab = 0;
  
  @override
  void initState() {
    super.initState();
    _loadPOIData();
  }

  Future<void> _loadPOIData() async {
    setState(() => isLoading = true);
    
    try {
      // Load custom pins
      final pinsResponse = await _makeRequest(
        'GET',
        '/api/trips/${widget.tripId}/custom-pins'
      );
      if (pinsResponse != null) {
        customPins = List<Map<String, dynamic>>.from(
          jsonDecode(pinsResponse)['custom_pins'] ?? []
        );
      }
      
      // Load POI tags
      final tagsResponse = await _makeRequest(
        'GET',
        '/api/poi-tags'
      );
      if (tagsResponse != null) {
        poiTags = List<Map<String, dynamic>>.from(
          jsonDecode(tagsResponse)['poi_tags'] ?? []
        );
      }
      
      // Load POI reviews
      final reviewsResponse = await _makeRequest(
        'GET',
        '/api/trips/${widget.tripId}/poi-reviews'
      );
      if (reviewsResponse != null) {
        poiReviews = List<Map<String, dynamic>>.from(
          jsonDecode(reviewsResponse)['poi_reviews'] ?? []
        );
      }
      
      // Load POI names
      final namesResponse = await _makeRequest(
        'GET',
        '/api/trips/${widget.tripId}/poi-names'
      );
      if (namesResponse != null) {
        poiNames = List<Map<String, dynamic>>.from(
          jsonDecode(namesResponse)['poi_names'] ?? []
        );
      }
      
      // Load seasonal alerts
      final alertsResponse = await _makeRequest(
        'GET',
        '/api/trips/${widget.tripId}/seasonal-alerts'
      );
      if (alertsResponse != null) {
        seasonalAlerts = List<Map<String, dynamic>>.from(
          jsonDecode(alertsResponse)['seasonal_alerts'] ?? []
        );
      }
      
      // Load crowd prediction
      final crowdResponse = await _makeRequest(
        'GET',
        '/api/trips/${widget.tripId}/crowd-prediction'
      );
      if (crowdResponse != null) {
        crowdPrediction = List<Map<String, dynamic>>.from(
          jsonDecode(crowdResponse)['crowd_prediction'] ?? []
        );
      }
      
      // Load facilities
      final facilitiesResponse = await _makeRequest(
        'GET',
        '/api/trips/${widget.tripId}/poi-facilities'
      );
      if (facilitiesResponse != null) {
        poiFacilities = List<Map<String, dynamic>>.from(
          jsonDecode(facilitiesResponse)['poi_facilities'] ?? []
        );
      }
      
      // Load experience bookings
      final bookingsResponse = await _makeRequest(
        'GET',
        '/api/trips/${widget.tripId}/experience-bookings'
      );
      if (bookingsResponse != null) {
        experienceBookings = List<Map<String, dynamic>>.from(
          jsonDecode(bookingsResponse)['experience_bookings'] ?? []
        );
      }
      
    } catch (e) {
      print('Error loading POI data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('載入資料失敗: $e'))
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  static const String _serverBase = '';

  Future<String?> _makeRequest(String method, String url, {Map<String, dynamic>? body}) async {
    try {
      final uri = Uri.parse('$_serverBase$url');
      final request = http.Request(method, uri);
      
      // Add headers
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer demo-token', // In real app, use actual token
      });
      
      // Add body for POST/PUT requests
      if (body != null && (method == 'POST' || method == 'PUT')) {
        request.body = jsonEncode(body);
      }
      
      // Send request
      final client = http.Client();
      final streamedResponse = await client.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw Exception('API request failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Request error: $e');
      throw e;
    }
  }

  Future<void> _addCustomPin() async {
    await showDialog(
      context: context,
      builder: (context) => _AddPinDialog(
        onAdd: (pinData) async {
          try {
            final response = await _makeRequest(
              'POST',
              '/api/trips/${widget.tripId}/custom-pins',
              body: pinData
            );
            
            if (response != null) {
              setState(() {
                customPins.add(jsonDecode(response)['custom_pin']);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('地標點已建立'))
              );
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('建立失敗: $e'))
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '景點管理',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF4ECDC4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Tab bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      _buildTabItem('地標點', 0),
                      _buildTabItem('標籤', 1),
                      _buildTabItem('評論', 2),
                      _buildTabItem('季節', 3),
                      _buildTabItem('人流', 4),
                      _buildTabItem('設施', 5),
                      _buildTabItem('附近', 6),
                      _buildTabItem('體驗', 7),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Tab content
                Expanded(
                  child: currentTab == 0
                      ? _buildCustomPinsTab()
                      : currentTab == 1
                          ? _buildTagsTab()
                          : currentTab == 2
                              ? _buildReviewsTab()
                              : currentTab == 3
                                  ? _buildSeasonalAlertsTab()
                                  : currentTab == 4
                                      ? _buildCrowdPredictionTab()
                                      : currentTab == 5
                                          ? _buildFacilitiesTab()
                                          : currentTab == 6
                                              ? _buildNearbySearchTab()
                                              : _buildExperienceBookingTab(),
                ),
              ],
            ),
      floatingActionButton: currentTab == 0
          ? FloatingActionButton(
              onPressed: _addCustomPin,
              backgroundColor: const Color(0xFF4ECDC4),
              child: const Icon(Icons.add),
            )
          : currentTab == 7
          ? FloatingActionButton(
              onPressed: _addExperienceBooking,
              backgroundColor: const Color(0xFF4ECDC4),
              child: const Icon(Icons.book_online),
            )
          : null,
    );
  }

  Widget _buildTabItem(String title, int index) {
    final isSelected = currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => currentTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4ECDC4) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomPinsTab() {
    if (customPins.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.place,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              '還沒有自訂地標點',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '點擊右下角按鈕添加新的地標點',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: customPins.length,
      itemBuilder: (context, index) {
        final pin = customPins[index];
        return _buildPinCard(pin);
      },
    );
  }

  Widget _buildPinCard(Map<String, dynamic> pin) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getPinIcon(pin['type']),
                  color: _getPinColor(pin['color']),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pin['name'] ?? '未命名地點',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (pin['address'] != null)
                        Text(
                          pin['address'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editPin(pin);
                    } else if (value == 'delete') {
                      _deletePin(pin['id']);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('編輯'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete),
                          SizedBox(width: 8),
                          Text('刪除'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (pin['description'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  pin['description'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getPinIcon(String? type) {
    switch (type) {
      case 'restaurant':
        return Icons.restaurant;
      case 'hotel':
        return Icons.hotel;
      case 'attraction':
        return Icons.attractions;
      case 'transport':
        return Icons.directions_car;
      case 'shopping':
        return Icons.shopping_bag;
      default:
        return Icons.place;
    }
  }

  Color _getPinColor(String? color) {
    if (color != null) {
      try {
        return Color(int.parse(color.replaceFirst('#', '0xFF')));
      } catch (e) {
        return Colors.orange;
      }
    }
    return Colors.orange;
  }

  Widget _buildTagsTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2,
      ),
      itemCount: poiTags.length,
      itemBuilder: (context, index) {
        final tag = poiTags[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Icon(
                  _getTagIcon(tag['icon']),
                  color: _getTagColor(tag['color']),
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  tag['name'] ?? '標籤',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  tag['category'] ?? '',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getTagIcon(String? icon) {
    if (icon == null) return Icons.tag;
    switch (icon) {
      case '🥟':
        return Icons.restaurant;
      case '🍣':
        return Icons.ramen_dining;
      case '🍜':
        return Icons.lunch_dining;
      case '🍝':
        return Icons.dinner_dining;
      case '🍔':
        return Icons.fastfood;
      case '📶':
        return Icons.wifi;
      case '🅿️':
        return Icons.local_parking;
      case '♿':
        return Icons.accessibility_new;
      case '🐕':
        return Icons.pets;
      default:
        return Icons.tag;
    }
  }

  Color _getTagColor(String? color) {
    if (color != null) {
      try {
        return Color(int.parse(color.replaceFirst('#', '0xFF')));
      } catch (e) {
        return Colors.blue;
      }
    }
    return Colors.blue;
  }

  Widget _buildReviewsTab() {
    if (poiReviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rate_review,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              '還沒有評論',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: poiReviews.length,
      itemBuilder: (context, index) {
        final review = poiReviews[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildStarRating(review['rating'] ?? 0),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        review['title'] ?? '評論',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (review['content'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      review['content'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${review['user_name'] ?? '使用者'} · ${review['visit_date'] ?? ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStarRating(int rating) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: index < rating ? Colors.amber : Colors.grey,
          size: 16,
        );
      }),
    );
  }

  Widget _buildSeasonalAlertsTab() {
    if (seasonalAlerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              '還沒有季節提醒',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: seasonalAlerts.length,
      itemBuilder: (context, index) {
        final alert = seasonalAlerts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _getSeasonIcon(alert['season']),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        alert['title'] ?? '季節提醒',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (alert['description'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      alert['description'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Text(
                        '${alert['destination_name'] ?? '地點'} · ${alert['alert_type'] ?? '提醒'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _getSeasonIcon(String? season) {
    switch (season) {
      case 'spring':
        return const Icon(Icons.local_florist, color: Colors.pink);
      case 'summer':
        return const Icon(Icons.wb_sunny, color: Colors.orange);
      case 'autumn':
        return const Icon(Icons.ac_unit, color: Colors.orange);
      case 'winter':
        return const Icon(Icons.snowing, color: Colors.blue);
      default:
        return const Icon(Icons.event);
    }
  }

  void _editPin(Map<String, dynamic> pin) {
    // Implementation for editing pin
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('編輯功能開發中'))
    );
  }

  void _deletePin(String pinId) {
    // Implementation for deleting pin
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('刪除功能開發中'))
    );
  }

  // Add controllers for nearby search
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController(text: '1000');
  final TextEditingController _nearbyTypeController = TextEditingController();

  // State for new data
  List<Map<String, dynamic>> crowdPrediction = [];
  List<Map<String, dynamic>> poiFacilities = [];
  Map<String, dynamic> _nearbyResults = {};
  List<Map<String, dynamic>> experienceBookings = [];

  // F32 - Crowd Prediction Tab
  Widget _buildCrowdPredictionTab() {
    if (crowdPrediction.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadCrowdPrediction,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: crowdPrediction.length,
        itemBuilder: (context, index) {
          final data = crowdPrediction[index];
          final crowdColor = data['crowd_level'] < 30
              ? Colors.green
              : data['crowd_level'] < 70
                  ? Colors.orange
                  : Colors.red;

          return Card(
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.accessibility_new, color: crowdColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data['name'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: crowdColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          data['crowd_status'],
                          style: TextStyle(
                            color: crowdColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text('預估等候時間: ${data['estimated_wait_time']}分鐘'),
                      const Spacer(),
                      Text(
                        '人流密度: ${data['crowd_level']}%',
                        style: TextStyle(color: crowdColor),
                      ),
                    ],
                  ),
                  if (data['time_factor'] != 1.0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '時間因素: ${(data['time_factor'] * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // F34 - Facilities Search Tab
  Widget _buildFacilitiesTab() {
    if (poiFacilities.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadFacilities,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: poiFacilities.length,
        itemBuilder: (context, index) {
          final category = poiFacilities[index];
          return Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        category['category']['icon'],
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        category['category']['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (category['facilities'].isEmpty)
                    const Text('附近沒有找到相關設施')
                  else
                    Column(
                      children: (category['facilities'] as List).map((facility) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${facility['facility_name']} (${facility['distance']}m)',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              Icon(
                                facility['is_available'] ? Icons.check_circle : Icons.cancel,
                                color: facility['is_available']
                                    ? Colors.green
                                    : Colors.red,
                                size: 16,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // F36 - Nearby Search Tab
  Widget _buildNearbySearchTab() {
    return Column(
      children: [
        // Search controls
        Card(
          elevation: 2,
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: '緯度',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        controller: _latController,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: '經度',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        controller: _lngController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: '搜尋範圍 (公尺)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        controller: _radiusController,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: '類型',
                          border: OutlineInputBorder(),
                        ),
                        controller: _nearbyTypeController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadNearbySearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECDC4),
                  ),
                  child: const Text('搜尋附近'),
                ),
              ],
            ),
          ),
        ),

        // Results
        Expanded(
          child: _nearbyResults.isEmpty
              ? const Center(child: Text('請輸入座標並搜尋'))
              : _buildNearbyResults(),
        ),
      ],
    );
  }

  // F37 - Experience Booking Tab
  Widget _buildExperienceBookingTab() {
    return Column(
      children: [
        // Bookings list
        Expanded(
          child: experienceBookings.isEmpty
              ? const Center(child: Text('尚無體驗預約'))
              : RefreshIndicator(
                  onRefresh: _loadExperienceBookings,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: experienceBookings.length,
                    itemBuilder: (context, index) {
                      final booking = experienceBookings[index];
                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    booking['status'] == 'confirmed'
                                        ? Icons.confirmation_number
                                        : Icons.cancel,
                                    color: booking['status'] == 'confirmed'
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      booking['experience_name'],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('日期: ${booking['date']}'),
                              Text('時間: ${booking['start_time']} - ${booking['end_time']}'),
                              Text('金額: ${booking['total_price']} TWD'),
                              Text('狀態: ${booking['status']}'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),

        // Add booking button
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _addExperienceBooking,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ECDC4),
            ),
            child: const Text('新增體驗預約'),
          ),
        ),
      ],
    );
  }

  Widget _buildNearbyResults() {
    return RefreshIndicator(
      onRefresh: _loadNearbySearch,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Restaurants
          if ((_nearbyResults['restaurants'] as List).isNotEmpty) ...[
            const Text(
              '餐廳',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4ECDC4),
              ),
            ),
            const SizedBox(height: 8),
            ...(_nearbyResults['restaurants'] as List).map((restaurant) {
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Text(restaurant['icon'] ?? '🍽️'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              restaurant['name'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${restaurant['distance']}m • ${restaurant['rating']} ⭐',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],

          // Convenience stores
          if ((_nearbyResults['convenience'] as List).isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              '便利商店',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4ECDC4),
              ),
            ),
            const SizedBox(height: 8),
            ...(_nearbyResults['convenience'] as List).map((store) {
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Text(store['icon'] ?? '🏪'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              store['name'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${store['distance']}m',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  // Load functions for new tabs
  Future<void> _loadCrowdPrediction() async {
    try {
      final response = await _makeRequest(
        'GET',
        '/api/trips/${widget.tripId}/crowd-prediction'
      );

      if (response != null) {
        final data = jsonDecode(response);
        setState(() {
          crowdPrediction = List<Map<String, dynamic>>.from(
            data['crowd_prediction'] ?? []
          );
        });
      }
    } catch (e) {
      print('Error loading crowd prediction: $e');
    }
  }

  Future<void> _loadFacilities() async {
    try {
      final response = await _makeRequest(
        'GET',
        '/api/trips/${widget.tripId}/poi-facilities'
      );

      if (response != null) {
        final data = jsonDecode(response);
        setState(() {
          poiFacilities = List<Map<String, dynamic>>.from(
            data['poi_facilities'] ?? []
          );
        });
      }
    } catch (e) {
      print('Error loading facilities: $e');
    }
  }

  Future<void> _loadNearbySearch() async {
    try {
      final lat = _latController.text;
      final lng = _lngController.text;
      final radius = _radiusController.text;
      final type = _nearbyTypeController.text;

      if (lat.isEmpty || lng.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請輸入緯度和經度'))
        );
        return;
      }

      final response = await _makeRequest(
        'GET',
        '/api/trips/${widget.tripId}/nearby-search'
            '?lat=$lat&lng=$lng&radius=$radius&type=$type'
      );

      if (response != null) {
        final data = jsonDecode(response);
        setState(() {
          _nearbyResults = Map<String, dynamic>.from(
            data['nearby_results'] ?? {}
          );
        });
      }
    } catch (e) {
      print('Error loading nearby search: $e');
    }
  }

  Future<void> _loadExperienceBookings() async {
    try {
      final response = await _makeRequest(
        'GET',
        '/api/trips/${widget.tripId}/experience-bookings'
      );

      if (response != null) {
        final data = jsonDecode(response);
        setState(() {
          experienceBookings = List<Map<String, dynamic>>.from(
            data['experience_bookings'] ?? []
          );
        });
      }
    } catch (e) {
      print('Error loading experience bookings: $e');
    }
  }

  Future<void> _addExperienceBooking() async {
    await showDialog(
      context: context,
      builder: (context) => _AddExperienceBookingDialog(
        onAdd: (bookingData) async {
          try {
            final response = await _makeRequest(
              'POST',
              '/api/trips/${widget.tripId}/experience-bookings',
              body: bookingData
            );

            if (response != null) {
              setState(() {
                experienceBookings.add(jsonDecode(response)['booking']);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('體驗預約已建立'))
              );
              _loadExperienceBookings(); // Refresh list
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('建立失敗: $e'))
            );
          }
        },
      ),
    );
  }
}

// Dialog for adding experience bookings
class _AddExperienceBookingDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;

  const _AddExperienceBookingDialog({
    super.key,
    required this.onAdd,
  });

  @override
  State<_AddExperienceBookingDialog> createState() => _AddExperienceBookingDialogState();
}

class _AddExperienceBookingDialogState extends State<_AddExperienceBookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _experienceNameController = TextEditingController();
  final TextEditingController _experienceTypeController = TextEditingController();
  final TextEditingController _providerNameController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  final TextEditingController _participantsController = TextEditingController();
  final TextEditingController _pricePerPersonController = TextEditingController();
  final TextEditingController _totalPriceController = TextEditingController();
  final TextEditingController _specialRequirementsController = TextEditingController();

  String _selectedExperienceType = 'tour';
  List<String> _availableExperienceTypes = [
    'tour', 'activity', 'workshop', 'cultural', 'adventure'
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新增體驗預約'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Experience details
              TextFormField(
                controller: _experienceNameController,
                decoration: const InputDecoration(
                  labelText: '體驗名稱 *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return '請輸入體驗名稱';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _selectedExperienceType,
                decoration: const InputDecoration(
                  labelText: '體驗類型 *',
                  border: OutlineInputBorder(),
                ),
                items: _availableExperienceTypes.map((type) {
                  final typeNames = {
                    'tour': '導覽',
                    'activity': '活動',
                    'workshop': '工作坊',
                    'cultural': '文化體驗',
                    'adventure': '冒險',
                  };
                  return DropdownMenuItem(
                    value: type,
                    child: Text(typeNames[type] ?? type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedExperienceType = value ?? 'tour';
                  });
                },
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return '請選擇體驗類型';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _providerNameController,
                decoration: const InputDecoration(
                  labelText: '提供者名稱',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              // Date and time
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: '日期 * (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return '請輸入日期';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startTimeController,
                      decoration: const InputDecoration(
                        labelText: '開始時間 * (HH:MM)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return '請輸入開始時間';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _endTimeController,
                      decoration: const InputDecoration(
                        labelText: '結束時間 * (HH:MM)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return '請輸入結束時間';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Participants and pricing
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _participantsController,
                      decoration: const InputDecoration(
                        labelText: '參與人數 *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return '請輸入參與人數';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _pricePerPersonController,
                      decoration: const InputDecoration(
                        labelText: '每人價格',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _totalPriceController,
                decoration: const InputDecoration(
                  labelText: '總價 *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return '請輸入總價';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _specialRequirementsController,
                decoration: const InputDecoration(
                  labelText: '特殊需求',
                  border: OutlineInputBorder(),
                  hintText: '例如: 飲食限制、無障礙需求等',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _submitBooking,
          child: const Text('新增'),
        ),
      ],
    );
  }

  void _submitBooking() {
    if (_formKey.currentState?.validate() ?? false) {
      final bookingData = {
        'experience_id': 'exp-${DateTime.now().millisecondsSinceEpoch}',
        'experience_name': _experienceNameController.text,
        'experience_type': _selectedExperienceType,
        'provider_name': _providerNameController.text.isEmpty ? null : _providerNameController.text,
        'date': _dateController.text,
        'start_time': _startTimeController.text,
        'end_time': _endTimeController.text,
        'participants': int.tryParse(_participantsController.text) ?? 1,
        'price_per_person': double.tryParse(_pricePerPersonController.text),
        'total_price': double.tryParse(_totalPriceController.text),
        'special_requirements': _specialRequirementsController.text.isEmpty 
            ? null 
            : _specialRequirementsController.text,
      };

      widget.onAdd(bookingData);
    }
  }
}

class _AddPinDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;

  const _AddPinDialog({required this.onAdd});

  @override
  State<_AddPinDialog> createState() => _AddPinDialogState();
}

class _AddPinDialogState extends State<_AddPinDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String? _selectedType;
  String _selectedColor = '#FF5733';

  final List<String> _pinTypes = [
    'restaurant',
    'hotel', 
    'attraction',
    'transport',
    'shopping',
    'other'
  ];

  final List<Map<String, dynamic>> _colorOptions = [
    {'color': '#FF5733', 'name': '橙色'},
    {'color': '#4ECDC4', 'name': '青色'},
    {'color': '#45B7D1', 'name': '藍色'},
    {'color': '#96CEB4', 'name': '綠色'},
    {'color': '#FECA57', 'name': '黃色'},
    {'color': '#B983FF', 'name': '紫色'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新增地標點'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '名稱',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入名稱';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: '類型',
                  border: OutlineInputBorder(),
                ),
                items: _pinTypes.map((type) {
                  final displayNames = {
                    'restaurant': '餐廳',
                    'hotel': '飯店',
                    'attraction': '景點',
                    'transport': '交通',
                    'shopping': '購物',
                    'other': '其他',
                  };
                  return DropdownMenuItem(
                    value: type,
                    child: Text(displayNames[type] ?? type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value;
                    _typeController.text = value ?? '';
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請選擇類型';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitudeController,
                      decoration: const InputDecoration(
                        labelText: '緯度',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '請輸入緯度';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _longitudeController,
                      decoration: const InputDecoration(
                        labelText: '經度',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '請輸入經度';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: '地址',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '描述',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  const Text('顏色：'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedColor,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.zero,
                      ),
                      items: _colorOptions.map((color) {
                        return DropdownMenuItem<String>(
                          value: color['color'],
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Color(int.parse(color['color']!.replaceFirst('#', '0xFF'))),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(color['name']!),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedColor = value ?? '#FF5733';
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _submitPin,
          child: const Text('新增'),
        ),
      ],
    );
  }

  void _submitPin() {
    if (_formKey.currentState?.validate() ?? false) {
      final pinData = {
        'name': _nameController.text,
        'type': _selectedType,
        'latitude': double.tryParse(_latitudeController.text),
        'longitude': double.tryParse(_longitudeController.text),
        'address': _addressController.text.isEmpty ? null : _addressController.text,
        'description': _descriptionController.text.isEmpty ? null : _descriptionController.text,
        'color': _selectedColor,
      };

      widget.onAdd(pinData);
    }
  }
}
