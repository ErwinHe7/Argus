import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'member_auth_signal_base.dart';

class BrowserMemberAuthSignal implements MemberAuthSignal {
  BrowserMemberAuthSignal({web.BroadcastChannel? channel})
    : _channel = channel ?? web.BroadcastChannel('ritual-member-auth-v1') {
    _channel.onmessage = ((web.MessageEvent event) {
      if (event.data.dartify() == 'logout') _events.add(null);
    }).toJS;
  }

  final web.BroadcastChannel _channel;
  final StreamController<void> _events = StreamController.broadcast(sync: true);

  @override
  Stream<void> get logoutEvents => _events.stream;

  @override
  void publishLogout() => _channel.postMessage('logout'.toJS);

  @override
  void close() {
    _channel.close();
    unawaited(_events.close());
  }
}

MemberAuthSignal createProductionMemberAuthSignal() =>
    BrowserMemberAuthSignal();
