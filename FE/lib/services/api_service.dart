import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../screens/auth/login_screen.dart';

class ApiService {
  static const String serverUrl = String.fromEnvironment('SERVER_URL', defaultValue: 'https://muse-rents.onrender.com');
  static const String baseUrl = '$serverUrl/api';

  static String getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$serverUrl$path';
  }

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static const Duration timeoutDuration = Duration(seconds: 60);

  static Future<http.Response> get(String endpoint) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl$endpoint'), headers: headers).timeout(timeoutDuration);
    return response;
  }

  static Future<http.Response> post(String endpoint, dynamic body) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: json.encode(body),
    ).timeout(timeoutDuration);
    return response;
  }

  static Future<http.Response> put(String endpoint, dynamic body) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: json.encode(body),
    ).timeout(timeoutDuration);
    return response;
  }

  static Future<http.Response> delete(String endpoint) async {
    final headers = await _getHeaders();
    final response = await http.delete(Uri.parse('$baseUrl$endpoint'), headers: headers).timeout(timeoutDuration);
    return response;
  }

  // Phương thức này gọi API nhẹ nhất để đánh thức server
  static Future<void> wakeUpServer() async {
    try {
      await http.get(Uri.parse('$baseUrl/health')).timeout(timeoutDuration);
    } catch (_) {
      // Bỏ qua lỗi vì mục đích chỉ là gửi request để kích hoạt server
    }
  }
}
