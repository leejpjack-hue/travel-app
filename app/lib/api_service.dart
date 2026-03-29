import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';
import 'token_storage.dart';

class ApiService {
  // Use empty string for same-origin deployment (Express serves both Flutter + API)
  static const String _baseUrl = '';

  // Singleton HTTP client (BrowserClient for Flutter web)
  static final http.Client _client = http.Client();

  // Get headers with authorization token
  Future<Map<String, String>> _getHeaders({bool withAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (withAuth) {
      final token = await TokenStorage.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // Authentication methods
  Future<http.Response> login(String email, String password) async {
    final url = Uri.parse('$_baseUrl/api/auth/login');
    final body = json.encode({
      'email': email,
      'password': password,
    });
    
    return await _client.post(
      url,
      headers: await _getHeaders(withAuth: false),
      body: body,
    );
  }

  Future<http.Response> register(String email, String name, String password) async {
    final url = Uri.parse('$_baseUrl/api/auth/register');
    final body = json.encode({
      'email': email,
      'name': name,
      'password': password,
    });

    return await _client.post(
      url,
      headers: await _getHeaders(withAuth: false),
      body: body,
    );
  }

  Future<http.Response> getCurrentUser() async {
    final url = Uri.parse('$_baseUrl/api/auth/me');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  // Trip methods
  Future<http.Response> getTrips() async {
    final url = Uri.parse('$_baseUrl/api/trips');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  Future<http.Response> getTrip(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  Future<http.Response> createTrip(Map<String, dynamic> tripData) async {
    final url = Uri.parse('$_baseUrl/api/trips');
    final body = json.encode(tripData);
    
    return await _client.post(
      url,
      headers: await _getHeaders(),
      body: body,
    );
  }

  Future<http.Response> updateTrip(String tripId, Map<String, dynamic> tripData) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId');
    final body = json.encode(tripData);
    
    return await _client.put(
      url,
      headers: await _getHeaders(),
      body: body,
    );
  }

  Future<http.Response> deleteTrip(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId');
    
    return await _client.delete(
      url,
      headers: await _getHeaders(),
    );
  }

  // PDF Export method
  Future<http.Response> exportPdf(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/export/pdf');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  // AI Modification method
  Future<http.Response> postAIModification(String tripId, String message) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/ai-modify');
    final body = json.encode({
      'message': message,
      'context': {
        'trip_name': 'Current Trip',
      }
    });
    
    return await _client.post(
      url,
      headers: await _getHeaders(),
      body: body,
    );
  }

  // AI Conversation History method
  Future<http.Response> getAIConversation(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/ai-conversation');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  // Memories Generation method
  Future<http.Response> getMemories(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/memories');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  // Timeline methods
  Future<http.Response> getTimeline(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/timeline');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  Future<http.Response> addTimelineItem(String tripId, Map<String, dynamic> itemData) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/timeline');
    final body = json.encode(itemData);
    
    return await _client.post(
      url,
      headers: await _getHeaders(),
      body: body,
    );
  }

  // Collaborators methods
  Future<http.Response> getCollaborators(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/collaborators');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  Future<http.Response> addCollaborator(String tripId, Map<String, dynamic> collaboratorData) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/collaborators');
    final body = json.encode(collaboratorData);
    
    return await _client.post(
      url,
      headers: await _getHeaders(),
      body: body,
    );
  }

  // Transportation methods
  Future<http.Response> getTransportationModes(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/transportation-modes');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  Future<http.Response> addTransportationMode(String tripId, Map<String, dynamic> modeData) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/transportation-modes');
    final body = json.encode(modeData);
    
    return await _client.post(
      url,
      headers: await _getHeaders(),
      body: body,
    );
  }

  // Destinations methods
  Future<http.Response> getDestinations(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/destinations');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  Future<http.Response> addDestination(String tripId, Map<String, dynamic> destinationData) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/destinations');
    final body = json.encode(destinationData);
    
    return await _client.post(
      url,
      headers: await _getHeaders(),
      body: body,
    );
  }

  // Nearby Search method
  Future<http.Response> getNearbySearch(String tripId, double lat, double lng, {int radius = 1000, String? type}) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/nearby-search?lat=$lat&lng=$lng&radius=$radius${type != null ? '&type=$type' : ''}');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  // Crowd Prediction method
  Future<http.Response> getCrowdPrediction(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/crowd-prediction');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  // Weather Alternatives method
  Future<http.Response> getWeatherAlternatives(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/weather-alternatives');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  // Custom Pins methods
  Future<http.Response> getCustomPins(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/custom-pins');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  Future<http.Response> addCustomPin(String tripId, Map<String, dynamic> pinData) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/custom-pins');
    final body = json.encode(pinData);
    
    return await _client.post(
      url,
      headers: await _getHeaders(),
      body: body,
    );
  }

  // GPS Tracking methods
  Future<http.Response> getGpsTrackingStatus(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/gps-tracking/status');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  Future<http.Response> startGpsTracking(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/gps-tracking/start');
    
    return await _client.post(
      url,
      headers: await _getHeaders(),
    );
  }

  Future<http.Response> stopGpsTracking(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/gps-tracking/stop');
    
    return await _client.post(
      url,
      headers: await _getHeaders(),
    );
  }

  // Digital Tickets methods
  Future<http.Response> getDigitalTickets(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/digital-tickets');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  Future<http.Response> addDigitalTicket(String tripId, Map<String, dynamic> ticketData) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/digital-tickets');
    final body = json.encode(ticketData);
    
    return await _client.post(
      url,
      headers: await _getHeaders(),
      body: body,
    );
  }

  // Alarm methods
  Future<http.Response> getAlarms(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/alarms');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  Future<http.Response> addAlarm(String tripId, Map<String, dynamic> alarmData) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/alarms');
    final body = json.encode(alarmData);
    
    return await _client.post(
      url,
      headers: await _getHeaders(),
      body: body,
    );
  }

  // Emergency Info methods
  Future<http.Response> getEmergencyInfo(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/emergency-info');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  Future<http.Response> updateEmergencyInfo(String tripId, Map<String, dynamic> infoData) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/emergency-info');
    final body = json.encode(infoData);
    
    return await _client.put(
      url,
      headers: await _getHeaders(),
      body: body,
    );
  }

  // Expense methods
  Future<http.Response> getExpenses(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/expenses');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  Future<http.Response> addExpense(String tripId, Map<String, dynamic> expenseData) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/expenses');
    final body = json.encode(expenseData);
    
    return await _client.post(
      url,
      headers: await _getHeaders(),
      body: body,
    );
  }

  // Shared Fund / Splits methods
  Future<http.Response> getSplits(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/splits');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  Future<http.Response> createSplit(String tripId, Map<String, dynamic> splitData) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/splits');
    final body = json.encode(splitData);
    
    return await _client.post(
      url,
      headers: await _getHeaders(),
      body: body,
    );
  }

  Future<http.Response> addSplitItem(String tripId, String splitId, Map<String, dynamic> itemData) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/splits/$splitId/items');
    final body = json.encode(itemData);
    
    return await _client.post(
      url,
      headers: await _getHeaders(),
      body: body,
    );
  }

  // Weather method
  Future<http.Response> getWeather(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/weather');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  // Visa info method
  Future<http.Response> getVisaInfo(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/visa-info');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  // Navigation method
  Future<http.Response> getNavigation(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/navigation');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  // Offline download method
  Future<http.Response> getOfflineDownload(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/offline-download');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  // Offline status method
  Future<http.Response> getOfflineStatus(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/offline-status');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  // Templates method
  Future<http.Response> getTemplates() async {
    final url = Uri.parse('$_baseUrl/api/templates');
    
    return await _client.get(
      url,
      headers: await _getHeaders(withAuth: false),
    );
  }

  // Schedule preferences methods
  Future<http.Response> getSchedulePreferences() async {
    final url = Uri.parse('$_baseUrl/api/users/me/preferences/schedule');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  Future<http.Response> updateSchedulePreferences(Map<String, dynamic> prefs) async {
    final url = Uri.parse('$_baseUrl/api/users/me/preferences/schedule');
    final body = json.encode(prefs);
    
    return await _client.put(
      url,
      headers: await _getHeaders(),
      body: body,
    );
  }

  // Transportation preferences methods
  Future<http.Response> getTransportationPreferences() async {
    final url = Uri.parse('$_baseUrl/api/users/me/preferences/transportation');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  Future<http.Response> updateTransportationPreferences(Map<String, dynamic> prefs) async {
    final url = Uri.parse('$_baseUrl/api/users/me/preferences/transportation');
    final body = json.encode(prefs);
    
    return await _client.put(
      url,
      headers: await _getHeaders(),
      body: body,
    );
  }

  // Base tour mode methods
  Future<http.Response> getBaseTourMode(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/base-tour-mode');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  Future<http.Response> enableBaseTourMode(String tripId, Map<String, dynamic> data) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/base-tour-mode');
    final body = json.encode(data);
    
    return await _client.post(
      url,
      headers: await _getHeaders(),
      body: body,
    );
  }

  // Route optimization method
  Future<http.Response> optimizeRoute(String tripId, Map<String, dynamic> data) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/route-optimization');
    final body = json.encode(data);
    
    return await _client.post(
      url,
      headers: await _getHeaders(),
      body: body,
    );
  }

  // Timeline update method
  Future<http.Response> updateTimelineItem(String tripId, String itemId, Map<String, dynamic> data) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/timeline/$itemId');
    final body = json.encode(data);
    
    return await _client.put(
      url,
      headers: await _getHeaders(),
      body: body,
    );
  }

  // Timeline reorder method
  Future<http.Response> reorderTimeline(String tripId, List<Map<String, dynamic>> itemOrders) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/timeline/reorder');
    final body = json.encode({'item_orders': itemOrders});
    
    return await _client.put(
      url,
      headers: await _getHeaders(),
      body: body,
    );
  }

  // Timeline conflicts method
  Future<http.Response> getTimelineConflicts(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/timeline/conflicts');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  // Smart fill method
  Future<http.Response> smartFill(String tripId, Map<String, dynamic> data) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/timeline/smart-fill');
    final body = json.encode(data);
    
    return await _client.post(
      url,
      headers: await _getHeaders(),
      body: body,
    );
  }

  // Travel times method
  Future<http.Response> getTravelTimes(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/travel-times');
    
    return await _client.get(
      url,
      headers: await _getHeaders(),
    );
  }

  // Generic helpers for screens that construct URLs directly
  Future<Map<String, String>> authHeaders() async => await _getHeaders();

  String get baseUrl => _baseUrl;
}
