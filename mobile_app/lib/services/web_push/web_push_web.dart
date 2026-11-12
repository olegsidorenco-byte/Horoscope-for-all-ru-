// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<bool> subscribeWebPush(String uid) async {
  try {
    if (js.context.hasProperty('cosmicSubscribeWebPush')) {
      js.context.callMethod('cosmicSubscribeWebPush', [uid]);
      return true;
    }
  } catch (_) {}
  return false;
}

Future<bool> sendTestWebPush(String uid) async {
  try {
    final res = await http.post(
      Uri.parse('https://cosmic-horoscope-api-688107707932.europe-west1.run.app/api/notifications/send-test'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': uid}),
    );
    return res.statusCode == 200;
  } catch (_) {
    return false;
  }
}
