// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/onboarding/data/onboarding_draft_store.dart';
import '../../features/onboarding/data/onboarding_repository.dart';
import '../../features/onboarding/domain/onboarding_draft.dart';
import '../api/ritual_api.dart';
import '../auth/auth_controller.dart';
import '../auth/member_auth.dart';
import 'member_bootstrap.dart';

enum EntryDestination {
  restoring,
  welcome,
  questionnaire,
  review,
  reconcile,
  authenticatedRecovery,
  finalizing,
  shell,
  failure,
}

enum EntryRetryAction { restore, discardDraft }

@immutable
class EntryCoordinatorState {
  const EntryCoordinatorState({
    required this.destination,
    this.draft,
    this.bootstrap,
    this.draftStatus = DraftReadStatus.empty,
    this.message,
    this.canRetry = false,
    this.retryAction,
  });

  final EntryDestination destination;
  final OnboardingDraft? draft;
  final MemberBootstrap? bootstrap;
  final DraftReadStatus draftStatus;
  final String? message;
  final bool canRetry;
  final EntryRetryAction? retryAction;
}

typedef ApplyMemberBootstrap = Future<void> Function(MemberBootstrap? value);
typedef RedeemBrokerageCompletion = Future<void> Function(String completion);

class EntryCoordinator extends ChangeNotifier {
  EntryCoordinator({
    required this.authController,
    required SessionBootstrapService bootstrapService,
    required OnboardingDraftStore draftStore,
    required OnboardingRepository onboardingRepository,
    ApplyMemberBootstrap? applyBootstrap,
  }) : _bootstrapService = bootstrapService,
       _draftStore = draftStore,
       _onboardingRepository = onboardingRepository,
       _applyBootstrap = applyBootstrap;

  final AuthController authController;
  final SessionBootstrapService _bootstrapService;
  final OnboardingDraftStore _draftStore;
  final OnboardingRepository _onboardingRepository;
  ApplyMemberBootstrap? _applyBootstrap;
  MemberNativeLinkPolicy? _nativeLinkPolicy;
  Future<Uri?> Function()? _initialNativeLink;
  Stream<Uri>? _nativeLinks;
  RedeemBrokerageCompletion? _redeemBrokerageCompletion;
  StreamSubscription<Uri>? _nativeLinkSubscription;

  EntryCoordinatorState _state = const EntryCoordinatorState(
    destination: EntryDestination.restoring,
  );
  EntryCoordinatorState get state => _state;

  OnboardingDraft? _draft;
  MemberBootstrap? _bootstrap;
  DraftReadStatus _draftStatus = DraftReadStatus.empty;

  void bindApplyBootstrap(ApplyMemberBootstrap applyBootstrap) {
    if (_applyBootstrap != null) {
      throw StateError('The entry coordinator is already bound.');
    }
    _applyBootstrap = applyBootstrap;
  }

  void bindBrokerageNativeLinks({
    required MemberNativeLinkPolicy policy,
    required Future<Uri?> Function() initialLink,
    required Stream<Uri> links,
    required RedeemBrokerageCompletion redeemCompletion,
  }) {
    if (_nativeLinkPolicy != null) {
      throw StateError('Brokerage native links are already bound.');
    }
    _nativeLinkPolicy = policy;
    _initialNativeLink = initialLink;
    _nativeLinks = links;
    _redeemBrokerageCompletion = redeemCompletion;
  }

  Future<void> saveDraft(OnboardingDraft draft) async {
    _draft = draft;
    _draftStatus = DraftReadStatus.available;
    if (draft.astrologyEnabled == true && draft.birthDate == null) {
      _set(_state.destination);
      return;
    }
    try {
      await _draftStore.save(draft);
      _set(_state.destination);
    } on Object {
      _set(_state.destination, message: _draftSaveMessage, canRetry: true);
    }
  }

  Future<void> beginQuestionnaire([OnboardingDraft? draft]) async {
    _draft = draft ?? _draft ?? const OnboardingDraft();
    _draftStatus = DraftReadStatus.available;
    _set(EntryDestination.questionnaire);
    await saveDraft(_draft!);
  }

  void resumeQuestionnaire() {
    if (_draft == null) {
      throw StateError('No reviewed onboarding draft is available to edit.');
    }
    _set(EntryDestination.questionnaire);
  }

  void pauseQuestionnaire() {
    _set(EntryDestination.welcome);
  }

  Future<void> restore() async {
    _set(EntryDestination.restoring);
    await _readDraft();
    await authController.restore();
    if (authController.state.phase == AuthPhase.signedIn) {
      await _reconcileAuthenticated();
      await _startBrokerageNativeLinks();
      return;
    }
    if (authController.state.phase == AuthPhase.failure) {
      _set(
        EntryDestination.failure,
        message: authController.state.message,
        canRetry: true,
        retryAction: EntryRetryAction.restore,
      );
      return;
    }
    _routeSignedOutDraft();
  }

  Future<void> resumeRecoveredSession() async {
    await _readDraft();
    await _reconcileAuthenticated();
    await _startBrokerageNativeLinks();
  }

  Future<void> signIn() async {
    await _readDraft();
    _set(EntryDestination.restoring);
    final result = await authController.signIn();
    switch (result) {
      case MemberAuthResult.authenticated:
        await _reconcileAuthenticated();
        await _startBrokerageNativeLinks();
      case MemberAuthResult.cancelled:
        _routeSignedOutDraft();
      case MemberAuthResult.unavailable:
        _set(
          EntryDestination.failure,
          message: 'Sign-in is temporarily unavailable.',
          canRetry: true,
          retryAction: EntryRetryAction.restore,
        );
    }
  }

  Future<void> createAccount(OnboardingDraft reviewedDraft) async {
    _draft = reviewedDraft;
    _draftStatus = DraftReadStatus.available;
    try {
      await _draftStore.save(reviewedDraft);
    } on Object {
      _set(EntryDestination.review, message: _draftSaveMessage, canRetry: true);
      return;
    }
    _set(EntryDestination.restoring);
    final result = await authController.signUp();
    switch (result) {
      case MemberAuthResult.authenticated:
        await _reconcileAuthenticated();
        await _startBrokerageNativeLinks();
      case MemberAuthResult.cancelled:
        _set(EntryDestination.review);
      case MemberAuthResult.unavailable:
        _set(
          EntryDestination.review,
          message: 'The connection was interrupted. Your answers are safe.',
          canRetry: true,
        );
    }
  }

  Future<void> attachDraft() async {
    final draft = _draft;
    final bootstrap = _bootstrap;
    if (draft == null || bootstrap == null) {
      throw StateError('No incomplete account and reviewed draft to attach.');
    }
    if (bootstrap.onboarding.isComplete) {
      await _finishCompleted(bootstrap);
      return;
    }
    final command = OnboardingFinalizationCommand.fromDraft(
      draft,
      expectedOnboardingVersion: bootstrap.onboarding.version,
    );
    _set(EntryDestination.finalizing);
    try {
      final completed = await _onboardingRepository.finalize(command);
      if (!completed.onboarding.isComplete) {
        throw const OnboardingFinalizationException(
          OnboardingFailureKind.terminal,
        );
      }
      await _finishCompleted(completed);
    } on OnboardingFinalizationException catch (error) {
      if (error.kind == OnboardingFailureKind.conflict ||
          error.kind == OnboardingFailureKind.retryable) {
        try {
          final refreshed = await _bootstrapService.bootstrap();
          if (refreshed.onboarding.isComplete) {
            _bootstrap = refreshed;
            await _finishCompleted(refreshed);
            return;
          }
          _bootstrap = refreshed;
          await _apply(refreshed);
        } on Object {
          // The protected draft remains authoritative for a same-key retry.
        }
      }
      _set(
        EntryDestination.reconcile,
        message: _messageFor(error.kind),
        canRetry:
            error.kind == OnboardingFailureKind.conflict ||
            error.kind == OnboardingFailureKind.retryable ||
            error.kind == OnboardingFailureKind.throttled,
      );
    } on Object {
      _set(
        EntryDestination.reconcile,
        message: 'Onboarding could not finish preparing. Your answers are safe; retry with the same reviewed details.',
        canRetry: true,
      );
    }
  }

  Future<void> discardDraft() async {
    try {
      await _draftStore.clear();
    } on Object {
      _set(
        EntryDestination.failure,
        message: 'This device could not discard the saved setup. Retry after unlocking it.',
        canRetry: true,
        retryAction: EntryRetryAction.discardDraft,
      );
      return;
    }
    _draft = null;
    _draftStatus = DraftReadStatus.empty;
    if (_bootstrap != null && !_bootstrap!.onboarding.isComplete) {
      _set(EntryDestination.authenticatedRecovery);
    } else {
      _set(EntryDestination.welcome);
    }
  }

  Future<void> logout() async {
    _draft = null;
    _draftStatus = DraftReadStatus.empty;
    _bootstrap = null;
    await _clearDraftBestEffort();
    try {
      await _apply(null);
    } on Object {
      // Authentication authority still wins over local feature cleanup.
    }
    await authController.logout();
    _set(EntryDestination.welcome);
  }

  Future<void> handleBrokerageNativeLink(Uri uri) async {
    final policy = _nativeLinkPolicy;
    final redeem = _redeemBrokerageCompletion;
    if (policy == null ||
        redeem == null ||
        authController.state.phase != AuthPhase.signedIn ||
        !policy.acceptsWebullCompletion(uri)) {
      return;
    }
    final values = uri.queryParametersAll['completion'];
    if (values == null || values.length != 1) return;
    try {
      await redeem(values.single);
      final refreshed = await _bootstrapService.bootstrap();
      await _apply(refreshed);
      _bootstrap = refreshed;
      _set(
        refreshed.canEnterMemberShell
            ? EntryDestination.shell
            : EntryDestination.authenticatedRecovery,
      );
    } on Object {
      // Completion links contain no local authority. A normal connection
      // status refresh recovers without retaining or reflecting the handle.
    }
  }

  Future<void> _startBrokerageNativeLinks() async {
    if (_nativeLinkSubscription != null || _nativeLinks == null) return;
    _nativeLinkSubscription = _nativeLinks!.listen(
      (uri) => unawaited(handleBrokerageNativeLink(uri)),
    );
    final initialLink = await _initialNativeLink?.call();
    if (initialLink != null) await handleBrokerageNativeLink(initialLink);
  }

  Future<void> refreshCompletedBootstrap() async {
    final refreshed = await _bootstrapService.bootstrap();
    if (!refreshed.onboarding.isComplete) {
      throw StateError('The member account is no longer onboarding complete.');
    }
    await _apply(refreshed);
    _bootstrap = refreshed;
    _set(EntryDestination.shell);
  }

  Future<void> _readDraft() async {
    final result = await _draftStore.read();
    _draftStatus = result.status;
    _draft = result.draft;
  }

  Future<void> _reconcileAuthenticated() async {
    late final MemberBootstrap bootstrap;
    try {
      bootstrap = await _bootstrapService.bootstrap();
      _bootstrap = bootstrap;
      await _apply(bootstrap);
    } on Object {
      _set(
        EntryDestination.failure,
        message: 'Your account could not be prepared. Please try again.',
        canRetry: true,
        retryAction: EntryRetryAction.restore,
      );
      return;
    }
    if (bootstrap.onboarding.isComplete) {
      _draft = null;
      _draftStatus = DraftReadStatus.empty;
      await _clearDraftBestEffort();
      _set(EntryDestination.shell);
    } else if (_draft != null) {
      _set(EntryDestination.reconcile);
    } else {
      _set(EntryDestination.authenticatedRecovery);
    }
  }

  Future<void> _finishCompleted(MemberBootstrap completed) async {
    _bootstrap = completed;
    try {
      await _apply(completed);
    } on Object {
      _set(
        EntryDestination.reconcile,
        message: 'Your account is complete, but this device could not prepare the app. Retry to finish locally.',
        canRetry: true,
      );
      return;
    }
    _draft = null;
    _draftStatus = DraftReadStatus.empty;
    await _clearDraftBestEffort();
    _set(EntryDestination.shell);
  }

  void _routeSignedOutDraft() {
    switch (_draftStatus) {
      case DraftReadStatus.available:
        _set(EntryDestination.questionnaire);
      case DraftReadStatus.locked:
        _set(
          EntryDestination.failure,
          message: 'Unlock this device to continue your private setup.',
          canRetry: true,
          retryAction: EntryRetryAction.restore,
        );
      case DraftReadStatus.undecryptable:
        _set(
          EntryDestination.failure,
          message: 'This saved setup cannot be opened. Restart safely.',
        );
      case DraftReadStatus.empty ||
          DraftReadStatus.expired ||
          DraftReadStatus.corrupted ||
          DraftReadStatus.orphaned:
        _set(EntryDestination.welcome);
    }
  }

  void _set(
    EntryDestination destination, {
    String? message,
    bool canRetry = false,
    EntryRetryAction? retryAction,
  }) {
    _state = EntryCoordinatorState(
      destination: destination,
      draft: _draft,
      bootstrap: _bootstrap,
      draftStatus: _draftStatus,
      message: message,
      canRetry: canRetry,
      retryAction: retryAction,
    );
    notifyListeners();
  }

  Future<void> _apply(MemberBootstrap? value) async {
    final callback = _applyBootstrap;
    if (callback != null) await callback(value);
  }

  Future<void> _clearDraftBestEffort() async {
    try {
      await _draftStore.clear();
    } on Object {
      // Server/auth authority is not reversed by unavailable device cleanup.
    }
  }

  @override
  void dispose() {
    unawaited(_nativeLinkSubscription?.cancel());
    super.dispose();
  }
}

const _draftSaveMessage =
    'Your answers are still editable, but could not be saved on this device. Unlock it and retry saving.';

String _messageFor(OnboardingFailureKind kind) => switch (kind) {
  OnboardingFailureKind.conflict =>
    'Your account changed. Review these answers before retrying.',
  OnboardingFailureKind.retryable =>
    'The connection was interrupted. Your answers are safe.',
  OnboardingFailureKind.throttled =>
    'Please wait a moment before trying again.',
  OnboardingFailureKind.validation =>
    'One or more answers need review before continuing.',
  OnboardingFailureKind.forbidden =>
    'This account cannot complete onboarding right now.',
  OnboardingFailureKind.terminal =>
    'Onboarding could not be completed. Your answers are safe.',
};
