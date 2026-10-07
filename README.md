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

<!--expanded-->
## Where Dart fits in a hiring product

Plenty of HR software is built with Flutter on the front end, and many teams like to share a language with their back end. A Dart server that receives an upload, calls a parser and returns a structured profile is a natural fit. The package provides the call and leaves the rest of the architecture to you.

The package returns ordinary maps. That choice keeps it small, and it lets you decide how typed your own models should be. A hiring product usually has a `Candidate` class with a dozen fields, and a mapping function from the parser's response to that class is the right place to put your rules about what to keep.

## Mapping the response to your own model

```dart
class Candidate {
  Candidate({required this.name, this.email, this.city, this.title, this.years, this.skills = const []});
  final String name;
  final String? email;
  final String? city;
  final String? title;
  final double? years;
  final List<String> skills;

  factory Candidate.fromResume(Map<String, dynamic> resume) {
    final contact = resume['contact'] as Map<String, dynamic>;
    final career = resume['career'] as Map<String, dynamic>;
    final emails = (contact['emails'] as List).cast<String>();
    final address = contact['address'] as Map<String, dynamic>?;
    final position = career['current_position'] as Map<String, dynamic>?;
    final skills = (resume['skills'] as Map<String, dynamic>)['technical'] as List;
    return Candidate(
      name: (contact['full_name'] as String?) ?? 'Unknown',
      email: emails.isEmpty ? null : emails.first,
      city: address?['city'] as String?,
      title: position?['title'] as String?,
      years: (career['total_experience_years'] as num?)?.toDouble(),
      skills: skills.cast<String>(),
    );
  }
}
```

Because every key is present in every response, the casts above are safe. Arrays are empty rather than missing, and scalars are `null` rather than absent. Those two guarantees remove most of the defensive code that parsing JSON normally needs.

## Upload handling on the server

A shelf handler that accepts a multipart upload, writes it to a temporary file and parses it takes about thirty lines. The important part is the cleanup. Always delete the temporary file in a `finally` block, whether parsing succeeded or not, because resumes contain personal information and should not linger on disk.

Return clear messages to the app. A 422 from the parser means the file had no readable text, so tell the user to try another format. A 413 means the document is too long, so suggest trimming it to the most recent pages. A 402 or a 401 is your own problem. Show a neutral message and alert your team, because a candidate cannot fix either of them.

## Control over what is extracted

The `ParseOptions` class lets you shape the call. `sections` limits extraction to the parts you need. `maxPages` caps the pages processed. `language` passes a hint. `excludeSensitive` and `anonymize` control the handling of personal data. Choose them per use case rather than globally. A sourcing tool might extract everything, while a screening screen shown to reviewers might use anonymized output.

```dart
const reviewerView = ParseOptions(excludeSensitive: true, anonymize: true);
const recruiterView = ParseOptions();

final forReviewers = await rr.parseFile(path, options: reviewerView);
```

Keep both versions if you need both audiences, and keep the original file so you can produce either on demand.

## Normalization for filters and search

Filters work best on canonical values. A Flutter app with a skills filter should offer fifty clean skill names, not three thousand spellings. Run your stored skills through the normalizer once, keep the canonical names and their types, and populate the filter from the distinct canonical values.

The skill normalizer classifies every result into one of fourteen types, among them programming language, framework, database, cloud, soft skill and spoken language. That lets you group a filter list sensibly. The title normalizer returns a canonical title, a seniority level and a job function, which lets you offer a seniority filter that works across companies with very different naming habits. The location normalizer adds an ISO country code and a metro area, which lets you offer a country filter that does not depend on how candidates spelled their city.

Each normalized item costs a tenth of a credit, and the package splits lists longer than a hundred automatically.

## Testing

The constructor accepts any `http.Client`, so tests can use `MockClient` from `package:http/testing.dart`. Write tests for three situations: a successful parse, an error status that your code should handle, and a batch normalization that spans two requests. The package's own tests cover the batching and the error mapping, and yours should cover how your application reacts.

## Related reading

For advertising teams who promote open roles, the guide to [persona based media planning](https://www.cookielessaudiences.com/use-cases/media-planning-by-persona.php) explains how to choose sites by the audience they reach instead of by tracking people. For acquisition teams who study recruiting and staffing businesses, [a precision machining sample report](https://www.acquisitionuniverse.com/samples/precision-machining.php) shows what evidence backed target screening looks like in another industry, with every claim tied to a sentence the company published.

<!--extra-->
## A short checklist before launch

Check that the key never ships inside an app bundle. Check that uploads are validated for type and size before they leave the device. Check that your server maps each status to a message a candidate can act on. Check that temporary files are deleted in a `finally` block. Check that parsed data and original files follow the same retention rule. And check that a person can correct a parsed field, because a parser is accurate without being infallible. Teams that walk through these six points before launch meet far fewer surprises in the first month.

<!--further-->
## Further reading

The [Dart language site](https://dart.dev/) documents isolates, records, patterns and null safety used above. For hiring teams that build screening tools, the [US Equal Employment Opportunity Commission](https://www.eeoc.gov/) publishes guidance on fair selection in employment, which is worth reading before you design any ranking on top of parsed resumes.

## Common questions

**Which Dart versions work?** Dart 3 and later.

**Does the package work in Flutter web?** It compiles, but you should not put an API key in a browser. Call your own server instead.

**What happens to my files?** The service processes documents in memory for the duration of the request and does not retain them.

**How do I get a key?** Pick a plan on the product site. The key is shown in your account after registration.

## Release notes

Version 1.0.0 is the first release. It supports parsing from text, files and links, three normalizers and typed exceptions. Expect new options to be added in minor versions, and read the changelog before upgrading.

## FAQ

**Which formats?** PDF, DOCX, RTF, ODT, HTML, TXT, spreadsheets and images.

**Does Flutter work?** Yes on the server side. On device, call your own backend.

**License?** MIT. info@alpha-quantum.com
