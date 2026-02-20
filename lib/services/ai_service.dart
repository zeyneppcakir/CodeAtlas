import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AIService {
  String get _baseUrl {
    // Web
    if (kIsWeb) return 'http://localhost:11434';

    // Android emulator -> host makine
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:11434';
    }

    // Windows/macOS/Linux
    return 'http://127.0.0.1:11434';
  }

  /// ✅ AddTaskScreen'in çağırdığı HALİ:
  /// prompt ver -> cevap al
  Future<String> generateTaskSuggestions({
    required String prompt,
    String model = 'qwen2.5:3b',
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "model": model,
        "prompt": prompt,
        "stream": false,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('LLM error (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body);
    return (data['response'] ?? '').toString().trim();
  }

  /// ✅ Eski kullanımın KIRILMASIN diye bunu da bırakalım (opsiyonel)
  Future<String> generateTaskSuggestionsForProject({
    required String projectName,
    required String primaryLanguage,
    String model = 'qwen2.5:3b',
  }) async {
    final prompt = '''
You are a senior software architect.

Project name: $projectName
Primary language: $primaryLanguage

Generate 5 actionable improvement tasks for this project.
Respond as a clean bullet list.
Keep each task short and clear.
''';

    return generateTaskSuggestions(prompt: prompt, model: model);
  }
}
