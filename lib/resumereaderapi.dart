// Client for the Resume Reader API.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _base = 'https://www.resumereaderapi.com/api/';

const _statusText = <int, String>{
  400: 'Missing or invalid input',
  401: 'Invalid API key',
  402: 'Insufficient credits, nothing was billed',
  413: 'Document beyond 20 pages, about 30,000 tokens or 10 MB, nothing was billed',
  422: 'File could not be read as a resume',
  429: 'Rate limit exceeded, 30 requests per 60 seconds per IP',
};

/// The HTTP status is always 200, so errors come from the JSON body status.
class ResumeReaderException implements Exception {
  ResumeReaderException(this.status, this.message, [this.body]);
  final int status;
  final String message;
  final Map<String, dynamic>? body;

  @override
  String toString() => 'ResumeReaderException($status): $message';
}

/// Optional parameters for the parse calls.
class ParseOptions {
  const ParseOptions({
    this.fieldNames,
    this.excludeSensitive = false,
    this.anonymize = false,
    this.maxPages,
    this.sections,
    this.language,
  });
  final String? fieldNames;
  final bool excludeSensitive;
  final bool anonymize;
  final int? maxPages;
  final List<String>? sections;
  final String? language;
}

class ResumeReader {
  ResumeReader(this.apiKey, {http.Client? client, this.timeout = const Duration(seconds: 120)})
      : _client = client ?? http.Client();

  final String apiKey;
  final Duration timeout;
  final http.Client _client;

  Future<Map<String, dynamic>> _post(String endpoint, Map<String, dynamic> payload) async {
    final res = await _client
        .post(Uri.parse('$_base$endpoint'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload))
        .timeout(timeout);
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw ResumeReaderException(res.statusCode, 'Response was not a JSON object');
    }
    final status = decoded['status'] is int ? decoded['status'] as int : 200;
    if (status != 200) {
      throw ResumeReaderException(status, _statusText[status] ?? 'API error', decoded);
    }
    return decoded;
  }

  Map<String, dynamic> _parsePayload(Map<String, dynamic> source, ParseOptions o) => {
        'api_key': apiKey,
        'schema_version': 2,
        ...source,
        if (o.fieldNames != null) 'field_names': o.fieldNames,
        if (o.excludeSensitive) 'exclude_sensitive': true,
        if (o.anonymize) 'anonymize': true,
        if (o.maxPages != null) 'max_pages': o.maxPages,
        if (o.sections != null) 'sections': o.sections,
        if (o.language != null) 'language': o.language,
      };

  Future<Map<String, dynamic>> parseText(String text, {ParseOptions options = const ParseOptions()}) =>
      _post('parse.php', _parsePayload({'text': text}, options));

  Future<Map<String, dynamic>> parseFile(String path, {ParseOptions options = const ParseOptions()}) async {
    final bytes = await File(path).readAsBytes();
    final name = path.split(Platform.pathSeparator).last;
    return _post('parse.php', _parsePayload({'file_base64': base64Encode(bytes), 'filename': name}, options));
  }

  Future<Map<String, dynamic>> parseUrl(String fileUrl, {ParseOptions options = const ParseOptions()}) =>
      _post('parse.php', _parsePayload({'file_url': fileUrl}, options));

  Future<Map<String, dynamic>> _normalize(String endpoint, String key, List<String> items) async {
    final results = <dynamic>[];
    var used = 0.0;
    num? remaining;
    for (var i = 0; i < items.length; i += 100) {
      final end = i + 100 > items.length ? items.length : i + 100;
      final body = await _post(endpoint, {'api_key': apiKey, key: items.sublist(i, end)});
      results.addAll((body['results'] as List?) ?? const []);
      used += (body['credits_used'] as num?)?.toDouble() ?? 0;
      remaining = (body['remaining_credits'] as num?) ?? remaining;
    }
    return {'results': results, 'credits_used': used, 'remaining_credits': remaining};
  }

  Future<Map<String, dynamic>> normalizeTitles(List<String> titles) => _normalize('normalize_title.php', 'titles', titles);
  Future<Map<String, dynamic>> normalizeSkills(List<String> skills) => _normalize('normalize_skills.php', 'skills', skills);
  Future<Map<String, dynamic>> normalizeLocations(List<String> locations) =>
      _normalize('normalize_locations.php', 'locations', locations);

  void close() => _client.close();
}
