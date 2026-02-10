import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AIService {
  String get _baseUrl {
    if (kIsWeb) return 'http://localhost:11434';
    return 'http://10.0.2.2:11434'; // android emulator
  }

  Future<String> generateTaskSuggestions({
    required String projectName,
    required String primaryLanguage,
  }) async {
    final prompt = '''
You are a senior software architect.

Project name: $projectName
Primary language: $primaryLanguage

Generate 5 actionable improvement tasks for this project.
Respond as a clean bullet list.
Keep each task short and clear.
''';

    final response = await http.post(
      Uri.parse('$_baseUrl/api/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
          {"model": "qwen2.5:3b", "prompt": prompt, "stream": false}),
    );

    if (response.statusCode != 200) {
      throw Exception('LLM error: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return (data['response'] ?? '').toString().trim();
  }
}
