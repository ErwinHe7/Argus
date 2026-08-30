import 'package:web/web.dart' as web;

Uri? currentMemberAuthCallbackUri() => Uri.tryParse(web.window.location.href);

void clearMemberAuthCallbackParameters(Uri uri) {
  web.window.history.replaceState(null, '', uri.path);
}
