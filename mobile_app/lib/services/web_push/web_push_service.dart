import 'web_push_stub.dart'
    if (dart.library.js) 'web_push_web.dart' as impl;

class WebPushService {
  static Future<bool> subscribe(String uid, {String? idToken}) =>
      impl.subscribeWebPush(uid, idToken: idToken);
  static Future<bool> sendTest(String uid, {String? idToken}) =>
      impl.sendTestWebPush(uid, idToken: idToken);
}
