import 'package:web/web.dart' as web;

Uri selectArgusAuthRedirect(List<Uri> targets) {
  final origin = Uri.tryParse(web.window.location.origin);
  if (origin != null) {
    for (final target in targets) {
      if (target.scheme == 'https' &&
          target.scheme == origin.scheme &&
          target.host == origin.host &&
          target.port == origin.port) {
        return target;
      }
    }
  }
  return targets.first;
}
