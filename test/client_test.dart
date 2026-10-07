import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:resumereaderapi/resumereaderapi.dart';
import 'package:test/test.dart';

void main() {
  test('normalizeSkills batches in groups of 100 and sums credits', () async {
    var calls = 0;
    final mock = MockClient((req) async {
      calls++;
      final items = (jsonDecode(req.body)['skills'] as List).length;
      return http.Response(
          jsonEncode({'status': 200, 'results': List.filled(items, {'input': 'x'}), 'credits_used': items * 0.1, 'remaining_credits': 10}),
          200);
    });
    final rr = ResumeReader('k', client: mock);
    final out = await rr.normalizeSkills(List.filled(150, 'js'));
    expect(calls, 2);
    expect((out['results'] as List).length, 150);
    expect((out['credits_used'] as double), closeTo(15, 0.001));
  });

  test('error status becomes an exception', () async {
    final mock = MockClient((req) async => http.Response('{"status":402}', 200));
    expect(() => ResumeReader('k', client: mock).parseText('cv'), throwsA(isA<ResumeReaderException>()));
  });
}
