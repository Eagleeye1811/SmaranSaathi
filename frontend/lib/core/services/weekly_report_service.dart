import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/weekly_report.dart';

/// Posts/fetches the doctor-only weekly clinical report. Same shape as
/// `TelehealthService`: best-effort over HTTP, silent no-op if the backend
/// is unreachable (the caregiver/patient apps never block on this).
class WeeklyReportService {
  WeeklyReportService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ??
            const String.fromEnvironment('MM_SYNC_BASE_URL', defaultValue: 'http://10.0.2.2:8000');

  final http.Client _client;
  final String baseUrl;

  /// Upserts the current cycle's report — called after every session, note
  /// or concern update, so the doctor's copy is never more than one write
  /// stale. No caregiver/patient-facing counterpart exists; this is the
  /// entire access-control mechanism for keeping it doctor-only.
  Future<void> upsertReport(WeeklyClinicalReport report) async {
    try {
      final Uri uri = Uri.parse('$baseUrl/api/v1/weekly-reports');
      await _client.post(
        uri,
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(report.toJson()),
      );
    } catch (e) {
      debugPrint('[WeeklyReportService] upsertReport error: $e');
    }
  }

  /// Fetches a patient's current-cycle report for the doctor's app.
  Future<WeeklyClinicalReport?> getReport(String patientId) async {
    try {
      final Uri uri = Uri.parse('$baseUrl/api/v1/weekly-reports/$patientId');
      final http.Response res = await _client.get(uri);
      if (res.statusCode == 200 && res.body.isNotEmpty && res.body != 'null') {
        return WeeklyClinicalReport.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('[WeeklyReportService] getReport error: $e');
    }
    return null;
  }
}
