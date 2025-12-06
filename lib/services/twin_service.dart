import 'dart:convert';
import 'package:http/http.dart' as http;

class TwinService {
  static const String _baseUrl = "https://gaming-twin-backend.onrender.com";
  static const Map<String, String> _headers = {
    "X-API-KEY": "secret",
    "Content-Type": "application/json",
  };

  // Fetch detailed twin (state + aggregates + thresholds)
  static Future<Map<String, dynamic>?> getTwin(String userId) async {
    final url = "$_baseUrl/digital-twin/$userId";

    try {
      final res = await http.get(Uri.parse(url), headers: _headers);

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      print("⚠️ Twin fetch failed ${res.statusCode}: ${res.body}");
      return null;
    } catch (e) {
      print("❌ Error fetching twin: $e");
      return null;
    }
  }

  // Fetch simplified reports (today, weekly, night, sessions)
  static Future<Map<String, dynamic>?> getReport(String userId) async {
    final url = "$_baseUrl/reports/$userId";

    try {
      final res = await http.get(Uri.parse(url), headers: _headers);

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      print("⚠️ Report fetch failed ${res.statusCode}: ${res.body}");
      return null;
    } catch (e) {
      print("❌ Error fetching report: $e");
      return null;
    }
  }
}
