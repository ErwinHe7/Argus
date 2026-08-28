import 'package:flutter/material.dart';

import 'demo_bootstrap.dart';
import 'demo_services.dart';
import 'web_frame_channel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final identity = DemoFrameIdentity.fromUri(Uri.base);
  final channel = BrowserDemoFrameChannel();
  try {
    final services = await DemoServices.bootstrap();
    runApp(
      _OwnedDemo(services: services, identity: identity, channel: channel),
    );
  } on Object {
    runApp(
      DemoStartupFailureApp(frameIdentity: identity, frameChannel: channel),
    );
  }
}

class _OwnedDemo extends StatefulWidget {
  const _OwnedDemo({
    required this.services,
    required this.identity,
    required this.channel,
  });

  final DemoServices services;
  final DemoFrameIdentity identity;
  final DemoFrameChannel channel;

  @override
  State<_OwnedDemo> createState() => _OwnedDemoState();
}

class _OwnedDemoState extends State<_OwnedDemo> {
  @override
  Widget build(BuildContext context) => DemoRitualInvestingApp(
    runtime: widget.services.runtime,
    frameIdentity: widget.identity,
    frameChannel: widget.channel,
  );

  @override
  void dispose() {
    widget.services.dispose();
    super.dispose();
  }
}
