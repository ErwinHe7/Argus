import 'dart:js_interop';

import 'demo_bootstrap.dart';

import 'package:web/web.dart' as web;

class BrowserDemoFrameChannel implements DemoFrameChannel {
  @override
  void send(DemoFrameEvent event) {
    web.window.parent?.postMessage(
      event.toMessage().jsify(),
      event.targetOrigin.toJS,
    );
  }
}
