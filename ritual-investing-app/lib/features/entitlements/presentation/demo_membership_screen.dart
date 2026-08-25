import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/presentation/demo_disclosure.dart';
import '../../../core/presentation/server_time.dart';
import '../application/entitlement_controller.dart';
import '../domain/model.dart';

class DemoCapabilityGate extends StatefulWidget {
  const DemoCapabilityGate({
    super.key,
    required this.controller,
    required this.capability,
    required this.returnLocation,
    required this.onOpenMembership,
    required this.child,
  });

  final EntitlementController controller;
  final DemoCapability capability;
  final String returnLocation;
  final VoidCallback onOpenMembership;
  final Widget child;

  @override
  State<DemoCapabilityGate> createState() => _DemoCapabilityGateState();
}

class _DemoCapabilityGateState extends State<DemoCapabilityGate> {
  @override
  void initState() {
    super.initState();
    if (widget.controller.phase == EntitlementPhase.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.controller.phase == EntitlementPhase.idle) {
          unawaited(widget.controller.load());
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final gate = widget.controller.gate(widget.capability);
      if (gate.isAllowed) return widget.child;
      return Scaffold(
        appBar: AppBar(title: Text(widget.capability.displayName)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              const _PersistentDemoNotice(),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(
                  gate.reason == CapabilityGateReason.loading
                      ? 'Checking Demo access'
                      : 'Explore Demo membership',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                gate.reason == CapabilityGateReason.staleAuthority
                    ? 'Fresh server membership is unavailable, so this capability remains closed. Cached plan names never grant access.'
                    : '${widget.capability.displayName} is not in the current server-provided capability set.',
              ),
              const SizedBox(height: 8),
              Text(widget.controller.explanationLabel),
              if (widget.controller.message case final message?) ...[
                const SizedBox(height: 12),
                Text(message),
              ],
              const SizedBox(height: 24),
              if (gate.reason == CapabilityGateReason.loading)
                const Center(child: CircularProgressIndicator())
              else ...[
                if (widget.controller.canUpgrade(widget.capability)) ...[
                  FilledButton(
                    key: const Key('capability-open-membership'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: widget.onOpenMembership,
                    child: const Text('Compare Demo plans'),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: widget.controller.load,
                  child: const Text('Refresh server access'),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class MembershipPlansScreen extends StatefulWidget {
  const MembershipPlansScreen({
    super.key,
    required this.controller,
    required this.onOpenCheckout,
    this.requestedCapability,
    this.returnLocation,
  });

  final EntitlementController controller;
  final DemoCapability? requestedCapability;
  final String? returnLocation;
  final ValueChanged<String> onOpenCheckout;

  @override
  State<MembershipPlansScreen> createState() => _MembershipPlansScreenState();
}

class _MembershipPlansScreenState extends State<MembershipPlansScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.controller.phase == EntitlementPhase.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.controller.phase == EntitlementPhase.idle) {
          unawaited(widget.controller.load());
        }
      });
    }
  }

  Future<void> _choosePremium() async {
    final capability =
        widget.requestedCapability ?? DemoCapability.futureMirror;
    final location = widget.returnLocation ?? '/ritual';
    widget.controller.prepareCheckout(
      capability: capability,
      returnLocation: location,
    );
    await widget.controller.createCheckout();
    if (!mounted) return;
    final checkout = widget.controller.checkout;
    if (checkout != null &&
        widget.controller.phase == EntitlementPhase.checkoutReview) {
      widget.onOpenCheckout(checkout.id);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      return Scaffold(
        appBar: AppBar(title: const Text('Demo membership')),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                const _PersistentDemoNotice(),
                const SizedBox(height: 20),
                Semantics(
                  header: true,
                  child: Text(
                    widget.requestedCapability == null
                        ? 'Choose your Demo path'
                        : 'Open ${widget.requestedCapability!.displayName}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: 8),
                Text(controller.explanationLabel),
                const SizedBox(height: 4),
                const Text(
                  'Personalization changes explanation style only. Server entitlement and capability codes always decide access.',
                ),
                if (controller.message case final message?) ...[
                  const SizedBox(height: 12),
                  Text(message),
                ],
                if (controller.phase == EntitlementPhase.loading) ...[
                  const SizedBox(height: 32),
                  const Center(child: CircularProgressIndicator()),
                ] else if (controller.plans.isEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'No authoritative Demo plans are available. Capability gates remain closed.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: controller.load,
                    child: const Text('Retry Demo plans'),
                  ),
                ] else ...[
                  const SizedBox(height: 20),
                  for (final plan in controller.plans) ...[
                    _PlanCard(
                      plan: plan,
                      isCurrent:
                          controller.entitlement?.status ==
                              DemoEntitlementStatus.active &&
                          controller.entitlement?.planCode == plan.code,
                      requestedCapability: widget.requestedCapability,
                      onChoose:
                          plan.code == DemoPlanCode.premiumDemo &&
                              controller.entitlement?.planCode !=
                                  DemoPlanCode.premiumDemo &&
                              controller.isFresh &&
                              widget.requestedCapability != null &&
                              widget.returnLocation != null
                          ? _choosePremium
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  OutlinedButton(
                    key: const Key('membership-restore'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: controller.hasProtectedCommand
                        ? null
                        : controller.restore,
                    child: const Text('Restore Demo access from Ritual'),
                  ),
                  if (controller.entitlement?.planCode ==
                      DemoPlanCode.premiumDemo) ...[
                    const SizedBox(height: 8),
                    if (controller.phase != EntitlementPhase.downgradeReview)
                      OutlinedButton(
                        key: const Key('membership-prepare-downgrade'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: controller.prepareDowngrade,
                        child: const Text('Review free Demo access'),
                      )
                    else
                      FilledButton.tonal(
                        key: const Key('membership-confirm-downgrade'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: controller.confirmDowngrade,
                        child: const Text('Confirm Demo downgrade'),
                      ),
                  ],
                  if (controller.canReviewProtectedCommand) ...[
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      key: const Key('membership-review-protected'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: controller.reviewProtectedCommand,
                      child: const Text('Review saved same-key command'),
                    ),
                    OutlinedButton(
                      key: const Key('membership-discard-protected'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: controller.discardProtectedCommand,
                      child: const Text(
                        'Refresh before abandoning saved retry',
                      ),
                    ),
                  ],
                  if (controller.phase ==
                      EntitlementPhase.reconciliationRequired) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      key: const Key('membership-reconcile'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: controller.retryReconciliation,
                      child: const Text('Refresh authoritative state'),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class DemoCheckoutScreen extends StatefulWidget {
  const DemoCheckoutScreen({
    super.key,
    required this.sessionId,
    required this.controller,
    required this.onReceipt,
    required this.onCancel,
  });

  final String sessionId;
  final EntitlementController controller;
  final VoidCallback onReceipt;
  final VoidCallback onCancel;

  @override
  State<DemoCheckoutScreen> createState() => _DemoCheckoutScreenState();
}

class _DemoCheckoutScreenState extends State<DemoCheckoutScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.controller.checkout?.id != widget.sessionId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(widget.controller.openCheckout(widget.sessionId));
        }
      });
    }
  }

  Future<void> _confirm() async {
    await widget.controller.confirmCheckout();
    if (mounted && widget.controller.phase == EntitlementPhase.receipt) {
      widget.onReceipt();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final checkout = controller.checkout;
      final plan = controller.plans
          .where((item) => item.code == DemoPlanCode.premiumDemo)
          .firstOrNull;
      return Scaffold(
        appBar: AppBar(title: const Text('Review Demo checkout')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              const _PersistentDemoNotice(),
              const SizedBox(height: 20),
              if (checkout == null || plan == null)
                const Center(child: CircularProgressIndicator())
              else ...[
                Semantics(
                  header: true,
                  child: Text(
                    plan.displayName,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: 8),
                Text(plan.priceCopy),
                const SizedBox(height: 12),
                _FactRow(label: 'Status', value: checkout.status.name),
                _FactRow(
                  label: 'Session version',
                  value: 'v${checkout.version}',
                ),
                _FactRow(
                  label: 'Expires',
                  value: ServerTime.timestamp(checkout.expiresAt),
                ),
                _Disclosure(disclosure: checkout.disclosure),
                if (controller.message case final message?) ...[
                  const SizedBox(height: 12),
                  Text(message),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('membership-confirm-checkout'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed:
                      controller.canConfirmCheckout &&
                          controller.phase != EntitlementPhase.confirming
                      ? _confirm
                      : null,
                  child: const Text('Confirm no-charge Demo access'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('membership-cancel-checkout'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: controller.hasProtectedCommand
                      ? null
                      : () {
                          controller.cancelCheckout();
                          widget.onCancel();
                        },
                  child: const Text('Leave Demo checkout'),
                ),
                if (controller.canReviewProtectedCommand)
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: controller.reviewProtectedCommand,
                    child: const Text('Review saved confirmation'),
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class DemoMembershipReceiptScreen extends StatefulWidget {
  const DemoMembershipReceiptScreen({
    super.key,
    required this.sessionId,
    required this.controller,
    required this.onContinue,
    required this.onBackToMembership,
  });

  final String sessionId;
  final EntitlementController controller;
  final ValueChanged<String> onContinue;
  final VoidCallback onBackToMembership;

  @override
  State<DemoMembershipReceiptScreen> createState() =>
      _DemoMembershipReceiptScreenState();
}

class _DemoMembershipReceiptScreenState
    extends State<DemoMembershipReceiptScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.controller.checkout?.id != widget.sessionId ||
        widget.controller.phase != EntitlementPhase.receipt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(widget.controller.openCheckout(widget.sessionId));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final entitled =
          controller.phase == EntitlementPhase.receipt &&
          controller.entitlement?.status == DemoEntitlementStatus.active &&
          controller.entitlement?.planCode == DemoPlanCode.premiumDemo;
      final returnContext = controller.returnContext;
      return Scaffold(
        appBar: AppBar(
          title: Text(entitled ? 'Demo receipt' : 'Demo membership status'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              const _PersistentDemoNotice(),
              const SizedBox(height: 24),
              Icon(
                entitled ? Icons.auto_awesome : Icons.sync,
                size: 48,
                semanticLabel: entitled
                    ? 'Demo access confirmed'
                    : 'Reconciling Demo access',
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  entitled
                      ? 'Premium Demo access is active'
                      : 'Confirming server authority',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 8),
              if (entitled) ...[
                const Text(
                  'Receipt amount: No charge. No card, bank, app store, billing account, or payment provider was used.',
                ),
                if (controller.entitlement case final entitlement?) ...[
                  const SizedBox(height: 12),
                  _FactRow(
                    label: 'Entitlement version',
                    value: 'v${entitlement.version}',
                  ),
                  _FactRow(
                    label: 'Started',
                    value: ServerTime.timestamp(entitlement.startsAt),
                  ),
                  _Disclosure(disclosure: entitlement.disclosure),
                ],
              ] else
                const Text(
                  'No Demo receipt is available until the exact checkout and fresh premium entitlement agree.',
                ),
              if (controller.message case final message?) ...[
                const SizedBox(height: 12),
                Text(message),
              ],
              const SizedBox(height: 24),
              if (entitled && returnContext != null)
                FilledButton(
                  key: const Key('membership-return-to-capability'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => widget.onContinue(returnContext.location),
                  child: Text(
                    'Continue to ${returnContext.capability.displayName}',
                  ),
                )
              else
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: controller.load,
                  child: const Text('Refresh server membership'),
                ),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: widget.onBackToMembership,
                child: const Text('Back to Demo membership'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.requestedCapability,
    required this.onChoose,
  });

  final DemoPlan plan;
  final bool isCurrent;
  final DemoCapability? requestedCapability;
  final Future<void> Function()? onChoose;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (isCurrent) const Chip(label: Text('Current')),
            ],
          ),
          const SizedBox(height: 6),
          Text(plan.priceCopy),
          const SizedBox(height: 12),
          for (final code in plan.capabilityCodes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(DemoCapability.fromCode(code)!.displayName),
                  ),
                ],
              ),
            ),
          if (requestedCapability case final capability?) ...[
            const SizedBox(height: 4),
            Text(
              plan.includes(capability)
                  ? '${capability.displayName} is included by the server capability code.'
                  : '${capability.displayName} is not included.',
            ),
          ],
          _Disclosure(disclosure: plan.disclosure),
          if (onChoose != null) ...[
            const SizedBox(height: 14),
            FilledButton(
              key: const Key('membership-choose-premium'),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onChoose,
              child: const Text('Review no-charge Demo access'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _PersistentDemoNotice extends StatelessWidget {
  const _PersistentDemoNotice();

  @override
  Widget build(BuildContext context) => const Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DemoBadge(),
      SizedBox(width: 10),
      Expanded(
        child: Text(
          'Fictional membership only · no charge · no card or bank · no app store · no real purchase · no payment provider',
        ),
      ),
    ],
  );
}

class _Disclosure extends StatelessWidget {
  const _Disclosure({required this.disclosure});

  final DemoDisclosure disclosure;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          disclosure.sourceLabel,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        Text('Observed ${ServerTime.timestamp(disclosure.observedAt)}'),
        for (final limitation in disclosure.limitations) Text('• $limitation'),
      ],
    ),
  );
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 132, child: Text(label)),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
