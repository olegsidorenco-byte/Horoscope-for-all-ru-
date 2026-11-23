// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../horoscope_sync_service.dart';

Future<bool> subscribeWebPush(String uid, {String? idToken}) async {
  try {
    if (idToken == null || idToken.isEmpty) return false;
    if (js.context.hasProperty('cosmicSubscribeWebPush')) {
      js.context.callMethod('cosmicSubscribeWebPush', [uid, idToken]);
      return true;
    }
  } catch (_) {}
  return false;
}

Future<bool> sendTestWebPush(String uid, {String? idToken}) async {
  try {
    if (idToken == null || idToken.isEmpty) return false;
    final res = await http.post(
      Uri.parse('${HoroscopeSyncService.apiBaseUrl}/api/notifications/send-test'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'user_id': uid}),
    );
    return res.statusCode == 200;
  } catch (_) {
    return false;
  }
}
