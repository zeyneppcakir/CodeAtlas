import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AIService {
  static const String geminiProvider = 'gemini';
  static const String ollamaProvider = 'ollama';

  static const String defaultGeminiModel = 'gemini-2.5-flash';
  static const String defaultOllamaModel = 'qwen2.5-coder:3b';

  static const List<String> supportedProviders = [
    geminiProvider,
    ollamaProvider,
  ];

  static const List<String> supportedOllamaModels = [
    'deepseek-coder',
    'qwen2.5-coder:3b',
    'qwen2.5:3b',
    'gemma4:e2b',
    'minimax-m2:cloud',
  ];

  String get _baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

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
      throw Exception('İstek metni boş olamaz.');
    }

    if (!supportedProviders.contains(cleanProvider)) {
      throw Exception('Geçersiz sağlayıcı: $cleanProvider');
    }

    final requestBody = <String, dynamic>{
      'prompt': cleanPrompt,
      'provider': cleanProvider,
    };

    if (cleanModel != null && cleanModel.isNotEmpty) {
      requestBody['model'] = cleanModel;
    }

    try {
      debugPrint('AIService POST => $_generateUri');
      debugPrint('AIService BODY => ${jsonEncode(requestBody)}');

      final response = await http
          .post(
            _generateUri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 180));

      debugPrint('AIService STATUS => ${response.statusCode}');
      debugPrint('AIService RESPONSE => ${response.body}');

      if (response.statusCode != 200) {
        throw Exception(
          'Yapay zekâ isteği başarısız oldu (${response.statusCode}). '
          'Detay: ${response.body}',
        );
      }

      final data = jsonDecode(response.body);

      if (data is! Map<String, dynamic>) {
        throw Exception('Beklenmeyen API cevabı alındı.');
      }

      final output = (data['output'] ?? '').toString().trim();

      if (output.isEmpty) {
        throw Exception('Model boş yanıt döndürdü.');
      }

      return output;
    } on TimeoutException {
      throw Exception(
        'İstek zaman aşımına uğradı. Model yavaş çalışıyor olabilir. '
        'Daha hızlı bir model seçmeyi veya tekrar denemeyi deneyebilirsin.',
      );
    } on http.ClientException catch (e) {
      throw Exception(
        'Backend bağlantı hatası: ${e.message}\n'
        'Adres: $_generateUri\n'
        'Backend açık mı kontrol et.',
      );
    } catch (e) {
      throw Exception('AIService hata verdi: $e');
    }
  }

  Future<String> generateTaskSuggestions({
    required String prompt,
    String provider = ollamaProvider,
    String model = defaultOllamaModel,
  }) async {
    return generate(
      prompt: prompt,
      provider: provider,
      model: model,
    );
  }

  Future<String> generateTaskSuggestionsForProject({
    required String projectName,
    required String primaryLanguage,
    String provider = ollamaProvider,
    String model = defaultOllamaModel,
  }) async {
    final prompt = '''
Sen deneyimli bir yazılım proje asistanısın.

Aşağıdaki proje bilgilerine göre 5 adet uygulanabilir geliştirme görevi üret.

Proje bilgileri:
- Proje adı: $projectName
- Baskın dil: $primaryLanguage

Kurallar:
- Yanıt tamamen Türkçe olsun.
- Markdown kullanma.
- Gereksiz giriş cümlesi yazma.
- Sadece görev başlıklarını yaz.
- Her satırda yalnızca 1 görev olsun.
- Her görev kısa, net ve uygulanabilir olsun.
- Genel ve tekrar eden maddeler yazma.
- Elinde olmayan bilgiye göre özellik uydurma.
- Görevler gerçek bir yazılım projesinde yapılabilir nitelikte olsun.

İstenen çıktı örneği:
Görev 1
Görev 2
Görev 3
''';

    return generate(
      prompt: prompt,
      provider: provider,
      model:
          provider.toLowerCase() == ollamaProvider ? model : defaultGeminiModel,
    );
  }

  Future<String> analyzeCode({
    required String codeOrPrompt,
    String provider = geminiProvider,
    String? model,
  }) async {
    final resolvedModel = model ??
        (provider.toLowerCase() == ollamaProvider
            ? defaultOllamaModel
            : defaultGeminiModel);

    final prompt = '''
Sen Türkçe yanıt veren dikkatli bir yazılım analiz asistanısın.

Aşağıdaki isteği analiz et ve kullanıcıya sade, anlaşılır ve düzenli bir cevap ver.

Kurallar:
-  Yanıt SADECE Türkçe olmalıdır.
- Markdown kullanma.
- Gereksiz giriş cümlesi kullanma.
- Bilgi eksikse bunu açıkça belirt.
- Uydurma bilgi verme.
- Çok uzun yazma ama yüzeysel de kalma.
- Gerekirse maddeli düz metin kullanabilirsin.
- Kod verilmişse:
  1. Kodun ne yaptığını açıkla
  2. Varsa sorunları belirt
  3. İyileştirme önerisi ver
- Soru verilmişse doğrudan soruya odaklan.

İstek:
$codeOrPrompt
''';

    return generate(
      prompt: prompt,
      provider: provider,
      model: resolvedModel,
    );
  }

  Future<String> analyzeProjectSummary({
    required String projectName,
    required String primaryLanguage,
    required int totalFiles,
    required int totalLines,
    required int nonEmptyLines,
    required Map<String, dynamic> languageDistribution,
    int? todoCount,
    int? fixmeCount,
    int? hackCount,
    int? bugCount,
    String provider = ollamaProvider,
    String? model,
  }) async {
    final resolvedModel = model ??
        (provider.toLowerCase() == ollamaProvider
            ? defaultOllamaModel
            : defaultGeminiModel);

    final prompt = '''
Sen Türkçe yanıt veren profesyonel bir yazılım analiz asistanısın.

Aşağıda bir projeye ait statik analiz verileri bulunmaktadır.
SADECE bu verilere dayanarak kısa, düzenli ve veri odaklı bir değerlendirme yap.

ÇOK ÖNEMLİ KURALLAR:
- Verilen sayılar dışında hiçbir sayı üretme.
- Verilen sayıları değiştirme, yuvarlama veya tahmin etme.
- Veri dışı yorum yapma.
- Güvenlik, performans, veritabanı, mimari, ölçeklenebilirlik veya kullanıcı deneyimi gibi konulara girme.
- Uydurma teknoloji, özellik veya teknik detay ekleme.
- Genel yazılım tavsiyesi verme.
- Eğer bir bilgi doğrudan verilmiyorsa ondan söz etme.

Yanıt yalnızca 3 bölümden oluşsun:
1. Genel Değerlendirme
2. Geliştirme Önerileri
3. Sonraki Adımlar

Proje verileri:
- Proje adı: $projectName
- Baskın dil: $primaryLanguage
- Toplam dosya: $totalFiles
- Toplam satır: $totalLines
- Boş olmayan satır: $nonEmptyLines
- Dil dağılımı: ${jsonEncode(languageDistribution)}
- TODO sayısı: ${todoCount ?? 0}
- FIXME sayısı: ${fixmeCount ?? 0}
- HACK sayısı: ${hackCount ?? 0}
- BUG sayısı: ${bugCount ?? 0}

Genel Değerlendirme bölümü:
- 2 veya 3 cümle yaz.
- Sadece verilen sayısal verileri kullan.
- Projenin büyüklüğünü dosya ve satır sayısına göre özetle.
- Baskın dili belirt.
- Dil dağılımında öne çıkan diğer dilleri sadece verilen dağılıma göre kısaca an.
- TODO, FIXME, HACK ve BUG sayılarını kısa bir gözlem olarak ekle.
- Bu sayılar üzerinden kalite, güvenlik veya risk yorumu yapma.

Geliştirme Önerileri bölümü:
- 3 madde yaz.
- Her madde kısa, net ve uygulanabilir olsun.
- Her öneri doğrudan verilen analiz verilerine bağlı olsun.
- Sadece şu alanlarda öneri ver:
  dosya bazlı inceleme, dil dağılımı takibi, not edilen TODO/FIXME kayıtlarının düzenli gözden geçirilmesi, analiz sonuçlarının periyodik izlenmesi.
- Genel ve alakasız öneriler verme.

Sonraki Adımlar bölümü:
- 2 veya 3 madde yaz.
- Somut ama genel adımlar ver.
- Sadece mevcut metrikleri temel al.
- Yeni varsayım veya yeni sayı üretme.

İstenen çıktı biçimi:

Genel Değerlendirme:
...

Geliştirme Önerileri:
1. ...
2. ...
3. ...

Sonraki Adımlar:
1. ...
2. ...
''';

    return generate(
      prompt: prompt,
      provider: provider,
      model: resolvedModel,
    );
  }
}
