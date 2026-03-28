import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/trip.dart';
import '../models/user.dart';

class ApiService {
  static const String _baseUrl = 'http://167.179.88.55:5005';

  // Get headers with authorization token
  Map<String, String> _getHeaders({bool withAuth = true}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    // Add authorization token if needed (in real app, you'd get this from storage)
    if (withAuth) {
      headers['Authorization'] = 'Bearer YOUR_TOKEN_HERE'; // Replace with actual token
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
    
    return await http.post(
      url,
      headers: _getHeaders(withAuth: false),
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
    
    return await http.post(
      url,
      headers: _getHeaders(withAuth: false),
      body: body,
    );
  }

  Future<http.Response> getCurrentUser() async {
    final url = Uri.parse('$_baseUrl/api/auth/me');
    
    return await http.get(
      url,
      headers: _getHeaders(),
    );
  }

  // Trip methods
  Future<http.Response> getTrips() async {
    final url = Uri.parse('$_baseUrl/api/trips');
    
    return await http.get(
      url,
      headers: _getHeaders(),
    );
  }

  Future<http.Response> getTrip(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId');
    
    return await http.get(
      url,
      headers: _getHeaders(),
    );
  }

  Future<http.Response> createTrip(Map<String, dynamic> tripData) async {
    final url = Uri.parse('$_baseUrl/api/trips');
    final body = json.encode(tripData);
    
    return await http.post(
      url,
      headers: _getHeaders(),
      body: body,
    );
  }

  Future<http.Response> updateTrip(String tripId, Map<String, dynamic> tripData) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId');
    final body = json.encode(tripData);
    
    return await http.put(
      url,
      headers: _getHeaders(),
      body: body,
    );
  }

  Future<http.Response> deleteTrip(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId');
    
    return await http.delete(
      url,
      headers: _getHeaders(),
    );
  }

  // PDF Export method
  Future<http.Response> exportPdf(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/export/pdf');
    
    return await http.get(
      url,
      headers: _getHeaders(),
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
    
    return await http.post(
      url,
      headers: _getHeaders(),
      body: body,
    );
  }

  // AI Conversation History method
  Future<http.Response> getAIConversation(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/ai-conversation');
    
    return await http.get(
      url,
      headers: _getHeaders(),
    );
  }

  // Memories Generation method
  Future<http.Response> getMemories(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/memories');
    
    return await http.get(
      url,
      headers: _getHeaders(),
    );
  }

  // Timeline methods
  Future<http.Response> getTimeline(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/timeline');
    
    return await http.get(
      url,
      headers: _getHeaders(),
    );
  }

  Future<http.Response> addTimelineItem(String tripId, Map<String, dynamic> itemData) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/timeline');
    final body = json.encode(itemData);
    
    return await http.post(
      url,
      headers: _getHeaders(),
      body: body,
    );
  }

  // Collaborators methods
  Future<http.Response> getCollaborators(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/collaborators');
    
    return await http.get(
      url,
      headers: _getHeaders(),
    );
  }

  Future<http.Response> addCollaborator(String tripId, Map<String, dynamic> collaboratorData) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/collaborators');
    final body = json.encode(collaboratorData);
    
    return await http.post(
      url,
      headers: _getHeaders(),
      body: body,
    );
  }

  // Transportation methods
  Future<http.Response> getTransportationModes(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/transportation-modes');
    
    return await http.get(
      url,
      headers: _getHeaders(),
    );
  }

  Future<http.Response> addTransportationMode(String tripId, Map<String, dynamic> modeData) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/transportation-modes');
    final body = json.encode(modeData);
    
    return await http.post(
      url,
      headers: _getHeaders(),
      body: body,
    );
  }

  // Destinations methods
  Future<http.Response> getDestinations(String tripId) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/destinations');
    
    return await http.get(
      url,
      headers: _getHeaders(),
    );
  }

  Future<http.Response> addDestination(String tripId, Map<String, dynamic> destinationData) async {
    final url = Uri.parse('$_baseUrl/api/trips/$tripId/destinations');
    final body = json.encode(destinationData);
    
    return await http.post(
      url,
      headers: _getHeaders(),
      body: body,
    );
  }
}