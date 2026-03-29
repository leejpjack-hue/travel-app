import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'trip_create_screen.dart';
import 'collaborators_screen.dart';
import 'timeline_screen.dart';
import 'transportation_screen.dart';
import 'poi_screen.dart';
import 'in_trip_screen.dart';
import 'shared_fund_screen.dart';
import 'pdf_export_screen.dart';
import 'login_screen.dart';
import 'token_storage.dart';
import 'models/trip.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoggedIn = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await TokenStorage.getToken();
    setState(() {
      _isLoggedIn = token != null && token.isNotEmpty;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZenVoyage',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4ECDC4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Noto Sans TC',
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
      home: _isChecking
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _isLoggedIn
              ? const HomeScreen()
              : LoginScreen(onLoginSuccess: () {
                  setState(() => _isLoggedIn = true);
                }),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeContent(),
    const TripCreateScreen(),
    const TransportationPlanningScreen(tripId: 'demo-trip-id'),
    const POIScreen(tripId: 'demo-trip-id'),
    const InTripScreen(tripId: 'demo-trip-id'),
    const SharedFundScreen(tripId: 'demo-trip-id'),
    PdfExportScreen(trip: Trip(id: 'demo-trip-id', name: '示範行程', destination: '示範目的地', startDate: DateTime.now(), endDate: DateTime.now().add(const Duration(days: 7)), status: 'draft', createdAt: DateTime.now(), updatedAt: DateTime.now())),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = 0; // Start with home screen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF4ECDC4),
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 0,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '首頁',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add),
            label: '創建',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: '交通',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.place),
            label: '景點',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: '旅途',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: '拆帳',
          ),
        ],
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ZenVoyage',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF4ECDC4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4ECDC4).withOpacity(0.1),
                    Colors.white,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF4ECDC4).withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '歡迎回來，旅行者！',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '開始規劃您的下一次冒險',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Quick actions
            const Text(
              '快速操作',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3436),
              ),
            ),

            const SizedBox(height: 16),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildActionCard(
                  context,
                  icon: Icons.flight_takeoff,
                  title: '創建行程',
                  subtitle: '開始新的旅行',
                  color: const Color(0xFF4ECDC4),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TripCreateScreen()),
                  ),
                ),
                _buildActionCard(
                  context,
                  icon: Icons.cloud,
                  title: '天氣預報',
                  subtitle: '查看行程天氣',
                  color: const Color(0xFFA8E6CF),
                ),
                _buildActionCard(
                  context,
                  icon: Icons.luggage,
                  title: '打包清單',
                  subtitle: '智能推薦',
                  color: const Color(0xFFFFD93D),
                ),
                _buildActionCard(
                  context,
                  icon: Icons.flight_land,
                  title: '航班資訊',
                  subtitle: '自動匯入',
                  color: const Color(0xFFFF6B6B),
                ),
                _buildActionCard(
                  context,
                  icon: Icons.place,
                  title: '景點管理',
                  subtitle: '自訂地標',
                  color: const Color(0xFF96CEB4),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const POIScreen(tripId: 'demo-trip-id')),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Recent trips
            const Text(
              '最近行程',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3436),
              ),
            ),

            const SizedBox(height: 16),

            _buildTripCard(
              title: '東京春節之旅',
              destination: '日本東京',
              date: '2024-02-10 - 2024-02-15',
              status: '規劃中',
            ),

            const SizedBox(height: 16),

            _buildTripCard(
              title: '大阪美食探險',
              destination: '日本大阪',
              date: '2024-03-01 - 2024-03-05',
              status: '已規劃',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 40,
              color: color,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2D3436),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard({
    required String title,
    required String destination,
    required String date,
    required String status,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3436),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: status == '規劃中'
                      ? const Color(0xFF4ECDC4).withOpacity(0.2)
                      : const Color(0xFFA8E6CF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: status == '規劃中'
                        ? const Color(0xFF4ECDC4)
                        : const Color(0xFF27AE60),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            destination,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            date,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class InTripScreen extends StatefulWidget {
  final String tripId;
  
  const InTripScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<InTripScreen> createState() => _InTripScreenState();
}

class _InTripScreenState extends State<InTripScreen> {
  // F40: Navigation data
  Map<String, dynamic> navigationData = {};
  bool isLoadingNavigation = true;
  
  // F41: Offline mode data
  Map<String, dynamic> offlineData = {};
  bool isLoadingOffline = true;
  
  // F42: GPS tracking data
  bool isTracking = false;
  Map<String, dynamic> trackingData = {};
  
  // F43: Digital tickets data
  List<Map<String, dynamic>> digitalTickets = [];
  bool isLoadingTickets = true;
  
  // F44: Alarms data
  List<Map<String, dynamic>> alarms = [];
  bool isLoadingAlarms = true;
  
  // F45: Emergency info
  Map<String, dynamic> emergencyInfo = {};
  bool isLoadingEmergency = true;
  
  // F46: Currency expenses
  List<Map<String, dynamic>> expenses = [];
  bool isLoadingExpenses = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadNavigationData(),
      _loadOfflineData(),
      _loadTrackingData(),
      _loadDigitalTickets(),
      _loadAlarms(),
      _loadEmergencyInfo(),
      _loadExpenses(),
    ]);
  }

  Future<void> _loadNavigationData() async {
    setState(() => isLoadingNavigation = true);
    try {
      final response = await _makeRequest(
        'GET',
        '/api/trips/${widget.tripId}/navigation'
      );
      if (response != null) {
        navigationData = jsonDecode(response);
      }
    } catch (e) {
      print('Navigation data error: $e');
    }
    setState(() => isLoadingNavigation = false);
  }

  Future<void> _loadOfflineData() async {
    setState(() => isLoadingOffline = true);
    try {
      final response = await _makeRequest(
        'GET',
        '/api/trips/${widget.tripId}/offline-status'
      );
      if (response != null) {
        offlineData = jsonDecode(response);
      }
    } catch (e) {
      print('Offline data error: $e');
    }
    setState(() => isLoadingOffline = false);
  }

  Future<void> _loadTrackingData() async {
    try {
      final response = await _makeRequest(
        'GET',
        '/api/trips/${widget.tripId}/gps-tracking/status'
      );
      if (response != null) {
        trackingData = jsonDecode(response);
        isTracking = trackingData['is_active'] ?? false;
      }
    } catch (e) {
      print('Tracking data error: $e');
    }
  }

  Future<void> _loadDigitalTickets() async {
    setState(() => isLoadingTickets = true);
    try {
      final response = await _makeRequest(
        'GET',
        '/api/trips/${widget.tripId}/digital-tickets'
      );
      if (response != null) {
        final data = jsonDecode(response);
        digitalTickets = List<Map<String, dynamic>>.from(data['digital_tickets'] ?? []);
      }
    } catch (e) {
      print('Digital tickets error: $e');
    }
    setState(() => isLoadingTickets = false);
  }

  Future<void> _loadAlarms() async {
    setState(() => isLoadingAlarms = true);
    try {
      final response = await _makeRequest(
        'GET',
        '/api/trips/${widget.tripId}/alarms'
      );
      if (response != null) {
        final data = jsonDecode(response);
        alarms = List<Map<String, dynamic>>.from(data['alarms'] ?? []);
      }
    } catch (e) {
      print('Alarms error: $e');
    }
    setState(() => isLoadingAlarms = false);
  }

  Future<void> _loadEmergencyInfo() async {
    setState(() => isLoadingEmergency = true);
    try {
      final response = await _makeRequest(
        'GET',
        '/api/trips/${widget.tripId}/emergency-info'
      );
      if (response != null) {
        emergencyInfo = jsonDecode(response);
      }
    } catch (e) {
      print('Emergency info error: $e');
    }
    setState(() => isLoadingEmergency = false);
  }

  Future<void> _loadExpenses() async {
    setState(() => isLoadingExpenses = true);
    try {
      final response = await _makeRequest(
        'GET',
        '/api/trips/${widget.tripId}/expenses'
      );
      if (response != null) {
        final data = jsonDecode(response);
        expenses = List<Map<String, dynamic>>.from(data['expenses'] ?? []);
      }
    } catch (e) {
      print('Expenses error: $e');
    }
    setState(() => isLoadingExpenses = false);
  }

  static const String _serverBase = '';

  Future<String?> _makeRequest(String method, String url, {Map<String, dynamic>? body}) async {
    final client = http.Client();
    final request = http.Request(method, Uri.parse('$_serverBase$url'));
    
    if (body != null) {
      request.body = jsonEncode(body);
      request.headers.addAll({
        'Content-Type': 'application/json',
      });
    }
    
    try {
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

  // F40: Start map navigation
  Future<void> _startNavigation() async {
    try {
      // For demo purposes, we'll just show a navigation dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('開始導航'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (navigationData['navigation'] != null) ...[
                Text('目的地: ${navigationData['navigation']['destination_name'] ?? '未設定'}'),
                Text('距離: ${navigationData['navigation']['total_distance'] ?? '0'} 公里'),
                Text('預計時間: ${navigationData['navigation']['estimated_time'] ?? '0'} 分鐘'),
                const SizedBox(height: 16),
                Text('路線指引:'),
                ...List.generate(
                  navigationData['navigation']['waypoints']?.length ?? 0,
                  (index) => Text('  ${index + 1}. ${navigationData['navigation']['waypoints'][index]['instruction'] ?? ''}'),
                ),
              ] else
                const Text('暫無導航資訊'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                // Open map app
                print('Opening map navigation...');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('正在開啟導航...')),
                );
              },
              child: const Text('開始導航'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('導航失敗: $e')),
      );
    }
  }

  // F41: Download offline data
  Future<void> _downloadOfflineData() async {
    setState(() => isLoadingOffline = true);
    try {
      final response = await _makeRequest(
        'GET',
        '/api/trips/${widget.tripId}/offline-download'
      );
      if (response != null) {
        final data = jsonDecode(response);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('離線套件下載中... 大小: ${data['package']['file_size_mb']} MB')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('下載失敗: $e')),
      );
    }
    setState(() => isLoadingOffline = false);
  }

  // F42: Start/stop GPS tracking
  Future<void> _toggleGpsTracking() async {
    try {
      if (isTracking) {
        // Stop tracking
        await _makeRequest(
          'POST',
          '/api/trips/${widget.tripId}/gps-tracking/stop'
        );
        isTracking = false;
      } else {
        // Start tracking
        await _makeRequest(
          'POST',
          '/api/trips/${widget.tripId}/gps-tracking/start'
        );
        isTracking = true;
      }
      _loadTrackingData();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GPS 追蹤失敗: $e')),
      );
    }
  }

  // F43: Add digital ticket
  Future<void> _addDigitalTicket() async {
    await showDialog(
      context: context,
      builder: (context) => _AddTicketDialog(
        onAdd: (ticketData) async {
          try {
            final response = await _makeRequest(
              'POST',
              '/api/trips/${widget.tripId}/digital-tickets',
              body: ticketData
            );
            
            if (response != null) {
              setState(() {
                final data = jsonDecode(response);
                digitalTickets.add(data['digital_ticket']);
              });
              Navigator.pop(context);
              _loadDigitalTickets();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('數位票券已新增'))
              );
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('新增失敗: $e'))
            );
          }
        },
      ),
    );
  }

  // F44: Add alarm
  Future<void> _addAlarm() async {
    await showDialog(
      context: context,
      builder: (context) => _AddAlarmDialog(
        onAdd: (alarmData) async {
          try {
            final response = await _makeRequest(
              'POST',
              '/api/trips/${widget.tripId}/alarms',
              body: alarmData
            );
            
            if (response != null) {
              setState(() {
                final data = jsonDecode(response);
                alarms.add(data['alarm']);
              });
              Navigator.pop(context);
              _loadAlarms();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('鬧鐘已設定'))
              );
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('設定失敗: $e'))
            );
          }
        },
      ),
    );
  }

  // F45: Add emergency contact
  Future<void> _addEmergencyContact() async {
    await showDialog(
      context: context,
      builder: (context) => _AddEmergencyContactDialog(
        onAdd: (contactData) async {
          try {
            final response = await _makeRequest(
              'POST',
              '/api/trips/${widget.tripId}/emergency-contacts',
              body: contactData
            );
            
            if (response != null) {
              Navigator.pop(context);
              _loadEmergencyInfo();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('緊急聯絡人已新增'))
              );
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('新增失敗: $e'))
            );
          }
        },
      ),
    );
  }

  // F46: Add expense
  Future<void> _addExpense() async {
    await showDialog(
      context: context,
      builder: (context) => _AddExpenseDialog(
        onAdd: (expenseData) async {
          try {
            final response = await _makeRequest(
              'POST',
              '/api/trips/${widget.tripId}/expenses',
              body: expenseData
            );
            
            if (response != null) {
              setState(() {
                final data = jsonDecode(response);
                expenses.add(data['expense']);
              });
              Navigator.pop(context);
              _loadExpenses();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('支出已記錄'))
              );
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('記錄失敗: $e'))
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
          '旅途執行',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF4ECDC4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // F40: Navigation Section
            _buildSectionCard(
              title: '一鍵導航',
              icon: Icons.navigation,
              child: isLoadingNavigation
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        if (navigationData['navigation'] != null) ...[
                          Text(
                            '目的地: ${navigationData['navigation']['destination_name'] ?? '未設定'}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text('距離: ${navigationData['navigation']['total_distance'] ?? '0'} 公里'),
                          Text('預計時間: ${navigationData['navigation']['estimated_time'] ?? '0'} 分鐘'),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _startNavigation,
                            icon: const Icon(Icons.directions),
                            label: const Text('開始導航'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4ECDC4),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ] else
                          const Text('暫無導航資訊'),
                      ],
                    ),
            ),

            const SizedBox(height: 16),

            // F41: Offline Mode Section
            _buildSectionCard(
              title: '離線模式',
              icon: Icons.offline_bolt,
              child: isLoadingOffline
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Text(
                          offlineData['available_offline'] == true 
                              ? '離線套件已下載'
                              : '離線套件未下載',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '狀態: ${offlineData['offline_status'] ?? 'unknown'}',
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _downloadOfflineData,
                          icon: const Icon(Icons.download),
                          label: const Text('下載離線套件'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA8E6CF),
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 16),

            // F42: GPS Tracking Section
            _buildSectionCard(
              title: 'GPS 追蹤',
              icon: Icons.location_on,
              child: Column(
                children: [
                  Text(
                    isTracking ? '正在追蹤中' : '追蹤已停止',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    trackingData['is_active'] == true 
                        ? '開始時間: ${trackingData['start_time'] ?? ''}'
                        : '目前沒有活動追蹤',
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _toggleGpsTracking,
                    icon: Icon(isTracking ? Icons.stop : Icons.play_arrow),
                    label: Text(isTracking ? '停止追蹤' : '開始追蹤'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isTracking ? const Color(0xFFFF6B6B) : const Color(0xFF4ECDC4),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // F43: Digital Tickets Section
            _buildSectionCard(
              title: '數位票券',
              icon: Icons.confirmation_number,
              child: isLoadingTickets
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Text('${digitalTickets.length} 個票券'),
                        const SizedBox(height: 8),
                        ...digitalTickets.take(3).map((ticket) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text('• ${ticket['ticket_name'] ?? 'Unknown'}'),
                        )),
                        if (digitalTickets.length > 3)
                          Text('...還有 ${digitalTickets.length - 3} 個'),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _addDigitalTicket,
                          icon: const Icon(Icons.add),
                          label: const Text('新增票券'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF96CEB4),
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 16),

            // F44: Alarms Section
            _buildSectionCard(
              title: '鬧鐘提醒',
              icon: Icons.alarm,
              child: isLoadingAlarms
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Text('${alarms.length} 個鬧鐘'),
                        const SizedBox(height: 8),
                        ...alarms.take(3).map((alarm) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text('• ${alarm['reminder_message'] ?? 'Unknown'}'),
                        )),
                        if (alarms.length > 3)
                          Text('...還有 ${alarms.length - 3} 個'),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _addAlarm,
                          icon: const Icon(Icons.add),
                          label: const Text('新增鬧鐘'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD93D),
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 16),

            // F45: Emergency Info Section
            _buildSectionCard(
              title: '緊急求助',
              icon: Icons.emergency,
              child: isLoadingEmergency
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        const Text('緊急聯絡人:'),
                        const SizedBox(height: 4),
                        Text(emergencyInfo['contacts']?.length?.toString() ?? '0'),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _addEmergencyContact,
                          icon: const Icon(Icons.person_add),
                          label: const Text('新增聯絡人'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B6B),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 16),

            // F46: Currency Expenses Section
            _buildSectionCard(
              title: '支出記帳',
              icon: Icons.money,
              child: isLoadingExpenses
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Text('${expenses.length} 筆支出'),
                        const SizedBox(height: 8),
                        Text('總計: TWD ${_calculateTotalExpenses()}'),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _addExpense,
                          icon: const Icon(Icons.add),
                          label: const Text('新增支出'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF96CEB4),
                            foregroundColor: Colors.black,
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF4ECDC4), size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  double _calculateTotalExpenses() {
    return expenses.fold(0, (total, expense) => total + (double.tryParse(expense['amount']?.toString() ?? '0') ?? 0));
  }
}

// F43: Add Digital Ticket Dialog
class _AddTicketDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;
  
  const _AddTicketDialog({required this.onAdd});

  @override
  State<_AddTicketDialog> createState() => _AddTicketDialogState();
}

class _AddTicketDialogState extends State<_AddTicketDialog> {
  final _formKey = GlobalKey<FormState>();
  final _ticketNameController = TextEditingController();
  final _providerController = TextEditingController();
  final _validFromController = TextEditingController();
  final _validUntilController = TextEditingController();
  final _ticketNumberController = TextEditingController();
  
  String _ticketType = 'ticket';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新增數位票券'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _ticketType,
              decoration: const InputDecoration(labelText: '票券類型'),
              items: [
                const DropdownMenuItem(value: 'ticket', child: Text('票券')),
                const DropdownMenuItem(value: 'pass', child: Text('通行證')),
                const DropdownMenuItem(value: 'coupon', child: Text('優惠券')),
              ],
              onChanged: (value) => setState(() => _ticketType = value!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ticketNameController,
              decoration: const InputDecoration(labelText: '票券名稱'),
              validator: (value) => value?.isEmpty ?? true ? '請輸入票券名稱' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _providerController,
              decoration: const InputDecoration(labelText: '發行商'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _validFromController,
              decoration: const InputDecoration(labelText: '生效日期 (YYYY-MM-DD)'),
              validator: (value) => value?.isEmpty ?? true ? '請輸入生效日期' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _validUntilController,
              decoration: const InputDecoration(labelText: '失效日期 (YYYY-MM-DD)'),
              validator: (value) => value?.isEmpty ?? true ? '請輸入失效日期' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ticketNumberController,
              decoration: const InputDecoration(labelText: '票券編號'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              widget.onAdd({
                'ticket_type': _ticketType,
                'ticket_name': _ticketNameController.text,
                'provider_name': _providerController.text,
                'valid_from': _validFromController.text,
                'valid_until': _validUntilController.text,
                'ticket_number': _ticketNumberController.text,
              });
            }
          },
          child: const Text('新增'),
        ),
      ],
    );
  }
}

// F44: Add Alarm Dialog
class _AddAlarmDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;
  
  const _AddAlarmDialog({required this.onAdd});

  @override
  State<_AddAlarmDialog> createState() => _AddAlarmDialogState();
}

class _AddAlarmDialogState extends State<_AddAlarmDialog> {
  final _formKey = GlobalKey<FormState>();
  final _scheduledTimeController = TextEditingController();
  final _reminderMessageController = TextEditingController();
  
  String _alarmType = 'reminder';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新增鬧鐘'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _alarmType,
              decoration: const InputDecoration(labelText: '鬧鐘類型'),
              items: [
                const DropdownMenuItem(value: 'reminder', child: Text('提醒')),
                const DropdownMenuItem(value: 'departure', child: Text('出發提醒')),
                const DropdownMenuItem(value: 'arrival', child: Text('到達提醒')),
              ],
              onChanged: (value) => setState(() => _alarmType = value!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _scheduledTimeController,
              decoration: const InputDecoration(labelText: '提醒時間 (YYYY-MM-DD HH:MM)'),
              validator: (value) => value?.isEmpty ?? true ? '請輸入提醒時間' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reminderMessageController,
              decoration: const InputDecoration(labelText: '提醒內容'),
              validator: (value) => value?.isEmpty ?? true ? '請輸入提醒內容' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              widget.onAdd({
                'alarm_type': _alarmType,
                'scheduled_time': _scheduledTimeController.text,
                'reminder_message': _reminderMessageController.text,
              });
            }
          },
          child: const Text('新增'),
        ),
      ],
    );
  }
}

// F45: Add Emergency Contact Dialog
class _AddEmergencyContactDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;
  
  const _AddEmergencyContactDialog({required this.onAdd});

  @override
  State<_AddEmergencyContactDialog> createState() => _AddEmergencyContactDialogState();
}

class _AddEmergencyContactDialogState extends State<_AddEmergencyContactDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _relationshipController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新增緊急聯絡人'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '姓名'),
              validator: (value) => value?.isEmpty ?? true ? '請輸入姓名' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _relationshipController,
              decoration: const InputDecoration(labelText: '關係'),
              validator: (value) => value?.isEmpty ?? true ? '請輸入關係' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: '電話'),
              validator: (value) => value?.isEmpty ?? true ? '請輸入電話' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              widget.onAdd({
                'name': _nameController.text,
                'relationship': _relationshipController.text,
                'phone': _phoneController.text,
                'email': _emailController.text,
              });
            }
          },
          child: const Text('新增'),
        ),
      ],
    );
  }
}

// F46: Add Expense Dialog
class _AddExpenseDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;
  
  const _AddExpenseDialog({required this.onAdd});

  @override
  State<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<_AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();
  
  String _currency = 'TWD';
  String _category = 'food';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新增支出'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: '金額'),
              keyboardType: TextInputType.number,
              validator: (value) => value?.isEmpty ?? true ? '請輸入金額' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _currency,
              decoration: const InputDecoration(labelText: '幣別'),
              items: [
                const DropdownMenuItem(value: 'TWD', child: Text('TWD')),
                const DropdownMenuItem(value: 'JPY', child: Text('JPY')),
                const DropdownMenuItem(value: 'USD', child: Text('USD')),
                const DropdownMenuItem(value: 'EUR', child: Text('EUR')),
              ],
              onChanged: (value) => setState(() => _currency = value!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: '類別'),
              items: [
                const DropdownMenuItem(value: 'food', child: Text('飲食')),
                const DropdownMenuItem(value: 'transport', child: Text('交通')),
                const DropdownMenuItem(value: 'accommodation', child: Text('住宿')),
                const DropdownMenuItem(value: 'shopping', child: Text('購物')),
                const DropdownMenuItem(value: 'entertainment', child: Text('娛樂')),
              ],
              onChanged: (value) => setState(() => _category = value!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dateController,
              decoration: const InputDecoration(labelText: '日期 (YYYY-MM-DD)'),
              validator: (value) => value?.isEmpty ?? true ? '請輸入日期' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: '描述'),
              validator: (value) => value?.isEmpty ?? true ? '請輸入描述' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              widget.onAdd({
                'amount': double.parse(_amountController.text),
                'currency': _currency,
                'category_id': _category,
                'expense_date': _dateController.text,
                'description': _descriptionController.text,
              });
            }
          },
          child: const Text('新增'),
        ),
      ],
    );
  }
}