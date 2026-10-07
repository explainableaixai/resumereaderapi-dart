# resumereaderapi for Dart

Parse resumes from a Dart server or command line tool. The package sends a file, text or link to the Resume Reader API and returns the candidate as a nested map.

Meant for backends. A key inside a client app is a key anyone can extract.

## pubspec.yaml

```yaml
dependencies:
  resumereaderapi: ^1.0.0
```

## Use

```dart
import 'package:resumereaderapi/resumereaderapi.dart';

Future<void> main() async {
  final rr = ResumeReader(const String.fromEnvironment('RESUME_KEY'));
  final out = await rr.parseFile('cv.pdf');
  final resume = out['resume'] as Map<String, dynamic>;

  print((resume['contact'] as Map)['full_name']);
  print((resume['career'] as Map)['seniority_level']);
  rr.close();
}
```

## Members

| Member | What it does |
|---|---|
| `parseText(text, {options})` | parse pasted text |
| `parseFile(path, {options})` | parse a local file |
| `parseUrl(url, {options})` | the service downloads the link |
| `normalizeTitles(list)` | canonical job titles with seniority |
| `normalizeSkills(list)` | canonical skills with a type |
| `normalizeLocations(list)` | city, region, country code |
| `ParseOptions` | field names, sensitivity, anonymize, pages, sections, language |
| `ResumeReaderException` | status, message, body |

## Product teams

If you build software for recruiters, a parser is a feature you would rather rent than write. The page for [HR tech products](https://www.resumereaderapi.com/use-cases/hr-tech-products.php) lists the usual integration patterns for vendors that embed parsing.

## French keys

```dart
final out = await rr.parseFile('cv.pdf', options: const ParseOptions(fieldNames: 'fr'));
```

Keys like `contact` become their French equivalents while values stay in the language of the document. The mapping is fixed. See the [French schema reference](https://www.resumereaderapi.com/api-v2-fr.php) for the full list.

## Sensitive data

```dart
const safe = ParseOptions(excludeSensitive: true, anonymize: true);
final out = await rr.parseText(text, options: safe);
```

Nine fields count as sensitive under GDPR, among them date of birth, gender and nationality. They are only filled when the document states them, and `excludeSensitive` skips them completely.

## Exceptions

```dart
try {
  await rr.parseFile('scan.jpg');
} on ResumeReaderException catch (e) {
  if (e.status == 422) {
    print('Could not read the image');
  } else if (e.status == 402) {
    print('Top up credits');
  } else {
    rethrow;
  }
}
```

Statuses: 400 input problem, 401 key, 402 credits, 413 size, 422 unreadable, 429 rate limit.

## Testing with a mock

```dart
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

final rr = ResumeReader('k', client: MockClient((_) async => http.Response('{"status":200,"resume":{}}', 200)));
```

## Batch normalization

```dart
final out = await rr.normalizeSkills(['JS', 'K8s', 'MS Excel']);
for (final r in out['results'] as List) {
  print('${r['input']} -> ${r['normalized_skill']}');
}
print('credits used: ${out['credits_used']}');
```

Anything above 100 items is split for you.

## FAQ

**Which formats?** PDF, DOCX, RTF, ODT, HTML, TXT, spreadsheets and images.

**Does Flutter work?** Yes on the server side. On device, call your own backend.

**License?** MIT. info@alpha-quantum.com
