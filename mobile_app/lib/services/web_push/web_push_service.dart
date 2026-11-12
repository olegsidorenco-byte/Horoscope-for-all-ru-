import 'web_push_stub.dart'
    if (dart.library.js) 'web_push_web.dart' as impl;

class WebPushService {
  static Future<bool> subscribe(String uid) => impl.subscribeWebPush(uid);
  static Future<bool> sendTest(String uid) => impl.sendTestWebPush(uid);
}
