import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AIService {
  String get _baseUrl {
    // Flutter Web
    if (kIsWeb) return 'http://127.0.0.1:8000';

    // Android emulator -> host machine
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    // Windows / macOS / Linux
    return 'http://127.0.0.1:8000';
  }

  Uri get _generateUri => Uri.parse('$_baseUrl/llm/generate');

  Future<String> generate({
    required String prompt,
    required String provider,
    String? model,
  }) async {
    final cleanPrompt = prompt.trim();
    final cleanProvider = provider.trim().toLowerCase();
    final cleanModel = model?.trim();

    if (cleanPrompt.isEmpty) {
      throw Exception('Prompt boş olamaz.');
    }

    if (cleanProvider != 'gemini' && cleanProvider != 'ollama') {
      throw Exception('Geçersiz provider: $cleanProvider');
    }

    final requestBody = {
      'prompt': cleanPrompt,
      'provider': cleanProvider,
      if (cleanProvider == 'ollama' &&
          cleanModel != null &&
          cleanModel.isNotEmpty)
        'model': cleanModel,
    };

    try {
      debugPrint('AIService POST => $_generateUri');
      debugPrint('AIService BODY => ${jsonEncode(requestBody)}');

      final response = await http
          .post(
            _generateUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 120));

      debugPrint('AIService STATUS => ${response.statusCode}');
      debugPrint('AIService RESPONSE => ${response.body}');

      if (response.statusCode != 200) {
        throw Exception(
          'AI error (${response.statusCode}): ${response.body}',
        );
      }

      final data = jsonDecode(response.body);

      if (data is! Map<String, dynamic>) {
        throw Exception('Beklenmeyen API cevabı alındı.');
      }

      return (data['output'] ?? '').toString().trim();
    } on TimeoutException {
      throw Exception(
        'İstek zaman aşımına uğradı. Model çok yavaş çalışıyor olabilir.',
      );
    } on http.ClientException catch (e) {
      throw Exception(
        'Backend bağlantı hatası: ${e.message}\n'
        'Adres: $_generateUri\n'
        'Backend açık mı ve CORS doğru mu kontrol et.',
      );
    } catch (e) {
      throw Exception('AIService hata verdi: $e');
    }
  }

  Future<String> generateTaskSuggestions({
    required String prompt,
    String provider = 'ollama',
    String model = 'qwen2.5:3b',
  }) async {
    return generate(
      prompt: prompt,
      provider: provider,
      model: provider.toLowerCase() == 'ollama' ? model : null,
    );
  }

  Future<String> generateTaskSuggestionsForProject({
    required String projectName,
    required String primaryLanguage,
    String provider = 'ollama',
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

    return generate(
      prompt: prompt,
      provider: provider,
      model: provider.toLowerCase() == 'ollama' ? model : null,
    );
  }

  Future<String> analyzeCode({
    required String codeOrPrompt,
    String provider = 'gemini',
    String? model,
  }) async {
    return generate(
      prompt: codeOrPrompt,
      provider: provider,
      model: provider.toLowerCase() == 'ollama' ? model : null,
    );
  }
}
