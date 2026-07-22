// One-off diagnostic: replicates TGApiService.setSprinkler's exact HTTP
// calls from the dev PC to compare against curl. Run:
//   dart run tool/valve_probe.dart
// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:http/http.dart' as http;

const base = 'https://api-emea03.telematics.guru';
const user = 'masood@onemindigitech.com';
const pass = 'Masood@234';

Future<void> main() async {
  final client = http.Client();
  final auth = await client.post(
    Uri.parse('$base/v1/user/authenticate'),
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: {'Username': user, 'Password': pass},
  );
  print('auth → ${auth.statusCode}');
  final token = (jsonDecode(auth.body) as Map)['access_token'] as String;

  final headers = {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  // Same call the app makes for "Activate Sprinkler".
  final post = await client.post(
    Uri.parse('$base/v2/asset/103028/immobilisation'),
    headers: headers,
    body: '0',
  );
  print('POST immobilisation → ${post.statusCode} body=${post.body}');
  client.close();
}
