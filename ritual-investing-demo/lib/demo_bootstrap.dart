import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/bootstrap/app_runtime.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/core/navigation/member_app_router.dart';

const demoCurrentProtocolVersion = 2;
const demoPreviousProtocolVersion = 1;

enum DemoEnvironment { prod, staging }

enum DemoFrameEventType { ready, error }

class DemoFrameIdentity {
  const DemoFrameIdentity({required this.environment, required this.attemptId});

  final DemoEnvironment environment;
  final String attemptId;

  factory DemoFrameIdentity.fromUri(Uri uri) {
    final environment = switch (uri.queryParameters['environment']) {
      'prod' => DemoEnvironment.prod,
      'staging' => DemoEnvironment.staging,
      null when uri.host == 'demo.just-build-this.app' => DemoEnvironment.prod,
      null when uri.host == 'demo-staging.just-build-this.app' =>
        DemoEnvironment.staging,
      _ => throw const FormatException(
        'Demo environment must be exactly prod or staging.',
      ),
    };
    final rawAttempt = uri.queryParameters['attempt'];
    final attempt =
        rawAttempt != null &&
            RegExp(r'^[A-Za-z0-9._-]{1,96}$').hasMatch(rawAttempt)
        ? rawAttempt
        : 'direct-load';
    return DemoFrameIdentity(environment: environment, attemptId: attempt);
  }
}

class DemoFrameEvent {
  const DemoFrameEvent({
    required this.type,
    required this.protocolVersion,
    required this.environment,
    required this.attemptId,
  });

  final DemoFrameEventType type;
  final int protocolVersion;
  final DemoEnvironment environment;
  final String attemptId;

  String get targetOrigin => switch (environment) {
    DemoEnvironment.prod => 'https://just-build-this.app',
    DemoEnvironment.staging => 'https://staging.just-build-this.app',
  };

  Map<String, Object> toMessage() => {
    'source': 'ritual-investing-demo',
    'type': switch (type) {
      DemoFrameEventType.ready => 'ritual-demo-ready',
      DemoFrameEventType.error => 'ritual-demo-error',
    },
    'protocolVersion': protocolVersion,
    'environment': environment.name,
    'attemptId': attemptId,
  };
}

abstract interface class DemoFrameChannel {
  void send(DemoFrameEvent event);
}

class RecordingDemoFrameChannel implements DemoFrameChannel {
  final List<DemoFrameEvent> events = [];

  @override
  void send(DemoFrameEvent event) => events.add(event);
}

class DemoRitualInvestingApp extends StatefulWidget {
  const DemoRitualInvestingApp({
    super.key,
    required this.runtime,
    required this.frameIdentity,
    required this.frameChannel,
  });

  final AppRuntime runtime;
  final DemoFrameIdentity frameIdentity;
  final DemoFrameChannel frameChannel;

  @override
  State<DemoRitualInvestingApp> createState() => _DemoRitualInvestingAppState();
}

class _DemoRitualInvestingAppState extends State<DemoRitualInvestingApp> {
  late final GoRouter _router = createMemberOnlyRouter(
    runtime: widget.runtime,
    assetPackage: 'ritual_investing_app',
  );
  late final SemanticsHandle _semanticsHandle;
  late final Listenable _readySignal;
  bool _announced = false;
  bool _readyCheckScheduled = false;

  @override
  void initState() {
    super.initState();
    _semanticsHandle = SemanticsBinding.instance.ensureSemantics();
    _readySignal = widget.runtime.dailyRitualController;
    _readySignal.addListener(_scheduleReadyCheck);
    _scheduleReadyCheck();
  }

  void _scheduleReadyCheck() {
    if (_announced || _readyCheckScheduled || !mounted) return;
    _readyCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readyCheckScheduled = false;
      _announceAfterPaint();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _announceAfterPaint() {
    if (_announced || !mounted) return;
    if (widget.runtime.entryGate != MemberEntryGate.member ||
        widget.runtime.featureScope == null ||
        widget.runtime.dailyRitualController.state.value == null) {
      return;
    }
    _announced = true;
    _readySignal.removeListener(_scheduleReadyCheck);
    _sendCompatible(DemoFrameEventType.ready);
  }

  void _sendCompatible(DemoFrameEventType type) {
    for (final version in const [
      demoCurrentProtocolVersion,
      demoPreviousProtocolVersion,
    ]) {
      widget.frameChannel.send(
        DemoFrameEvent(
          type: type,
          protocolVersion: version,
          environment: widget.frameIdentity.environment,
          attemptId: widget.frameIdentity.attemptId,
        ),
      );
    }
  }

  ThemeMode get _themeMode =>
      switch (widget.runtime.memberBootstrap?.themePreference) {
        MemberThemePreference.dark => ThemeMode.dark,
        MemberThemePreference.system => ThemeMode.system,
        _ => ThemeMode.light,
      };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.runtime,
    builder: (context, _) => MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Ritual Investing Demo',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      routerConfig: _router,
    ),
  );

  @override
  void dispose() {
    _readySignal.removeListener(_scheduleReadyCheck);
    _semanticsHandle.dispose();
    _router.dispose();
    super.dispose();
  }
}

class DemoStartupFailureApp extends StatefulWidget {
  const DemoStartupFailureApp({
    super.key,
    required this.frameIdentity,
    required this.frameChannel,
  });

  final DemoFrameIdentity frameIdentity;
  final DemoFrameChannel frameChannel;

  @override
  State<DemoStartupFailureApp> createState() => _DemoStartupFailureAppState();
}

class _DemoStartupFailureAppState extends State<DemoStartupFailureApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final version in const [
        demoCurrentProtocolVersion,
        demoPreviousProtocolVersion,
      ]) {
        widget.frameChannel.send(
          DemoFrameEvent(
            type: DemoFrameEventType.error,
            protocolVersion: version,
            environment: widget.frameIdentity.environment,
            attemptId: widget.frameIdentity.attemptId,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Ritual Investing Demo',
    theme: AppTheme.light,
    home: const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'The Demo could not start.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ),
  );
}
