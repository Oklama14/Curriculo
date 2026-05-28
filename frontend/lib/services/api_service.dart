import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/job_model.dart';
import '../models/history_model.dart';
import 'auth_service.dart';

class ApiService {
  final String baseUrl;
  final String? apiKey;

  ApiService({
    this.baseUrl = 'http://localhost:8000',
    this.apiKey,
  });

  Future<Map<String, String>> _getHeaders() async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = await AuthService().idToken;
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (apiKey != null && apiKey!.isNotEmpty) {
      headers['X-API-Key'] = apiKey!;
    }
    return headers;
  }

  // Resolve um caminho de arquivo retornado do backend em uma URL válida
  String resolveUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    // Garante que o caminho relativo comece com barra
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$cleanPath';
  }

  // GET /api/v1/history - Lista histórico de otimizações
  Future<List<HistoryItem>> fetchHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/history/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        // O body vem codificado em UTF-8
        final decoded = utf8.decode(response.bodyBytes);
        return HistoryItem.fromJsonList(decoded);
      } else {
        throw Exception('Falha ao obter histórico: Status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de conexão ao buscar histórico: $e');
    }
  }

  // GET /api/v1/jobs - Lista vagas coletadas (scraped)
  Future<List<ScrapedJob>> fetchJobs() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/jobs/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final decoded = utf8.decode(response.bodyBytes);
        return ScrapedJob.fromJsonList(decoded);
      } else {
        throw Exception('Falha ao obter vagas: Status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de conexão ao buscar vagas: $e');
    }
  }

  // POST /api/v1/jobs/scrape - Dispara o scraper para uma URL
  Future<ScrapedJob> scrapeJob(String url) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/jobs/scrape'),
        headers: await _getHeaders(),
        body: json.encode({'url': url}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = utf8.decode(response.bodyBytes);
        return ScrapedJob.fromJson(json.decode(decoded));
      } else {
        final errJson = json.decode(utf8.decode(response.bodyBytes));
        final errMsg = errJson['detail'] ?? 'Erro desconhecido';
        throw Exception('Falha ao coletar vaga: $errMsg');
      }
    } catch (e) {
      throw Exception('Erro de conexão ao executar scraper: $e');
    }
  }

  // POST /api/v1/tailor - Otimiza o currículo para uma descrição de vaga
  Future<Map<String, dynamic>> tailorResume({
    required String jobDescription,
    bool tailorSkills = true,
    bool compilePdf = true,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/tailor/'),
        headers: await _getHeaders(),
        body: json.encode({
          'job_description': jobDescription,
          'tailor_skills': tailorSkills,
          'compile_pdf': compilePdf,
        }),
      );

      if (response.statusCode == 200) {
        final decoded = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> data = json.decode(decoded);
        return {
          'success': data['success'] ?? false,
          'diff': data['diff'] ?? '',
          'tex_content': data['tex_content'] ?? '',
          'pdf_url': resolveUrl(data['pdf_url']),
          'tex_url': resolveUrl(data['tex_url']),
          'errors': data['errors'] ?? [],
        };
      } else {
        final errJson = json.decode(utf8.decode(response.bodyBytes));
        final errMsg = errJson['detail'] ?? 'Erro no processamento do Gemini/LaTeX';
        throw Exception('Falha no processo de Tailor: $errMsg');
      }
    } catch (e) {
      throw Exception('Erro de conexão ao processar o Tailoring: $e');
    }
  }

  // GET /api/v1/profile/ - Obtém perfil do usuário
  Future<Map<String, dynamic>> fetchProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/profile/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('Falha ao obter perfil: Status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de conexão ao buscar perfil: $e');
    }
  }

  // PUT /api/v1/profile/ - Atualiza perfil do usuário
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/v1/profile/'),
        headers: await _getHeaders(),
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('Falha ao atualizar perfil: Status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de conexão ao atualizar perfil: $e');
    }
  }

  // POST /api/v1/apply/prepare - Prepara candidatura semi-automática
  Future<Map<String, dynamic>> prepareApplication({
    required String jobUrl,
    required String tailorRunId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/apply/prepare'),
        headers: await _getHeaders(),
        body: json.encode({
          'job_url': jobUrl,
          'tailor_run_id': tailorRunId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['pdf_url'] != null) {
          data['pdf_url'] = resolveUrl(data['pdf_url']);
        }
        return data;
      } else {
        throw Exception('Falha ao preparar candidatura: Status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de conexão ao preparar candidatura: $e');
    }
  }
}
