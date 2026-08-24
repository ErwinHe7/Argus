import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/admin_session_controller.dart';
import '../application/workspace_controller.dart';
import '../data/admin_gateway.dart';
import '../domain/admin_models.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    required this.destination,
    required this.session,
    required this.gateway,
    super.key,
  });
  final AdminDestination destination;
  final AdminSessionController session;
  final AdminGateway gateway;
  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  late final WorkspaceController _controller;
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = WorkspaceController(
      destination: widget.destination,
      gateway: widget.gateway,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.keyK, meta: true):
          _FocusSearchIntent(),
      SingleActivator(LogicalKeyboardKey.keyK, control: true):
          _FocusSearchIntent(),
    },
    child: Actions(
      actions: {
        _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
          onInvoke: (_) => _searchFocus.requestFocus(),
        ),
      },
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) => _body(context),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _body(BuildContext context) {
    final writePermission = widget.destination.writePermission;
    final canWrite =
        writePermission != null && widget.session.permits(writePermission);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 680,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.destination.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(widget.destination.subtitle),
                ],
              ),
            ),
            if (canWrite) _createControl(),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          focusNode: _searchFocus,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Filter this page',
            helperText: 'Press ⌘K or Ctrl+K to focus',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 18),
        if (_controller.loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_controller.error != null)
          Expanded(child: Center(child: Text(_controller.error!)))
        else
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final list = _recordList();
                final detail = _detail(canWrite);
                return constraints.maxWidth >= 900
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 4, child: list),
                          const SizedBox(width: 20),
                          Expanded(flex: 5, child: detail),
                        ],
                      )
                    : _controller.selected == null
                    ? list
                    : detail;
              },
            ),
          ),
      ],
    );
  }

  Widget _recordList() {
    if (_controller.records.isEmpty) {
      return const Card(
        child: Center(child: Text('No records match this bounded page.')),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        itemCount: _controller.records.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final record = _controller.records[index];
          return Semantics(
            label: 'Editorial status ${record.status}',
            child: ListTile(
              selected: _controller.selected?.id == record.id,
              title: Text(record.title),
              subtitle: Text('${record.status} · version ${record.version}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _controller.select(record),
            ),
          );
        },
      ),
    );
  }

  Widget _detail(bool canWrite) {
    final record = _controller.selected;
    if (record == null) {
      return const Card(
        child: Center(
          child: Text('Select a record to inspect its safe staff view.'),
        ),
      );
    }
    return Semantics(
      label: 'Editorial status ${record.status}',
      child: Card(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(record.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Status: ${record.status}'),
              Text('Version: ${record.version}'),
              const SizedBox(height: 24),
              if (canWrite) _recordActions(record),
            ],
          ),
        ),
      ),
    );
  }

  Widget _createControl() {
    if (widget.destination.kind == AdminWorkspaceKind.editorial) {
      return FilledButton.icon(
        onPressed: _showDraftEditor,
        icon: const Icon(Icons.add),
        label: const Text('New draft'),
      );
    }
    if (widget.destination.route == '/operations/media') {
      return FilledButton.icon(
        onPressed: () => _fieldAction('Create media upload request', const [
          _FieldSpec(
            'mime_type',
            'MIME type',
            options: ['image/jpeg', 'image/png', 'image/webp'],
          ),
          _FieldSpec('byte_size', 'Byte size', kind: _FieldKind.integer),
          _FieldSpec(
            'checksum',
            'SHA-256 checksum',
            helper: 'Exactly 64 lowercase hexadecimal characters.',
          ),
        ], widget.gateway.createMediaUpload),
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload request'),
      );
    }
    if (widget.destination.route == '/catalog/schedules') {
      return FilledButton.icon(
        onPressed: () => _fieldAction('Create ritual schedule', const [
          _FieldSpec('local_date', 'Local date', helper: 'YYYY-MM-DD'),
          _FieldSpec('mode', 'Ritual mode', options: ['tarot', 'astrology']),
          _FieldSpec('revision_id', 'Approved revision ID'),
          _FieldSpec('audience', 'Audience', options: ['member', 'public']),
          _FieldSpec(
            'effective_at',
            'Effective timestamp',
            helper: 'ISO-8601 timestamp with timezone.',
          ),
        ], widget.gateway.createSchedule),
        icon: const Icon(Icons.event_available),
        label: const Text('New schedule'),
      );
    }
    if (widget.destination.kind == AdminWorkspaceKind.catalog) {
      return FilledButton.icon(
        onPressed: () => _fieldAction(
          'Create ${widget.destination.title}',
          _catalogFields(),
          (payload) =>
              widget.gateway.createCatalog(widget.destination, payload),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New record'),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _recordActions(AdminRecord record) {
    final actions = <Widget>[];
    void add(String label, IconData icon, Future<void> Function() action) {
      actions.add(
        OutlinedButton.icon(
          onPressed: () => _controller.runAction(action),
          icon: Icon(icon),
          label: Text(label),
        ),
      );
    }

    if (widget.destination.kind == AdminWorkspaceKind.editorial) {
      add(
        'New revision',
        Icons.copy_all_outlined,
        () => _payloadAction(
          'Create revision payload',
          (payload) => widget.gateway.createRevision(
            widget.destination,
            record,
            payload,
          ),
        ),
      );
      add(
        'Edit draft',
        Icons.edit_outlined,
        () => _payloadAction(
          'Edit typed draft payload',
          (payload) =>
              widget.gateway.patchRevision(widget.destination, record, payload),
        ),
      );
      add(
        'Preview',
        Icons.visibility_outlined,
        () => widget.gateway.preview(widget.destination, record),
      );
      add(
        'Request review',
        Icons.rate_review_outlined,
        () => widget.gateway.requestReview(widget.destination, record),
      );
      if (widget.session.permits(AdminPermission.editorialReview)) {
        add(
          'Approve',
          Icons.check_circle_outline,
          () => widget.gateway.decideReview(
            widget.destination,
            record,
            'approved',
          ),
        );
        add(
          'Request changes',
          Icons.change_circle_outlined,
          () => widget.gateway.decideReview(
            widget.destination,
            record,
            'changes_requested',
          ),
        );
      }
      if (widget.session.permits(AdminPermission.editorialPublish)) {
        actions.add(
          FilledButton.icon(
            onPressed: _confirmPublish,
            icon: const Icon(Icons.publish_outlined),
            label: const Text('Publish'),
          ),
        );
        add(
          'Withdraw',
          Icons.unpublished_outlined,
          () => widget.gateway.withdraw(widget.destination, record),
        );
      }
      if (widget.destination.route == '/editorial/coven' &&
          widget.session.permits(AdminPermission.covenVerify)) {
        add('Verify qualification', Icons.verified_outlined, _verifyCoven);
      }
    } else if (widget.destination.route == '/catalog/schedules') {
      add(
        'Edit schedule',
        Icons.edit_calendar_outlined,
        () => _fieldPayloadAction('Edit schedule', const [
          _FieldSpec('revision_id', 'Approved revision ID'),
          _FieldSpec(
            'effective_at',
            'Effective timestamp',
            helper: 'ISO-8601 timestamp with timezone.',
          ),
        ], (payload) => widget.gateway.patchSchedule(record, payload)),
      );
      add(
        'Withdraw schedule',
        Icons.event_busy,
        () => widget.gateway.withdrawSchedule(record),
      );
    } else if (widget.destination.kind == AdminWorkspaceKind.catalog) {
      add(
        'Edit record',
        Icons.edit_outlined,
        () => _fieldPayloadAction(
          'Edit ${widget.destination.title}',
          _catalogFields(forPatch: true),
          (payload) =>
              widget.gateway.patchCatalog(widget.destination, record, payload),
        ),
      );
      if (widget.destination.route == '/catalog/assets') {
        add(
          'Add metric snapshot',
          Icons.query_stats,
          () => _fieldPayloadAction('Add immutable metric snapshot', const [
            _FieldSpec('observed_at', 'Observed timestamp'),
            _FieldSpec(
              'price_minor',
              'Demo price (minor units)',
              kind: _FieldKind.integer,
            ),
            _FieldSpec(
              'change_bps',
              'Change (basis points)',
              kind: _FieldKind.nullableInteger,
            ),
            _FieldSpec(
              'expense_ratio_bps',
              'Expense ratio (basis points)',
              kind: _FieldKind.nullableInteger,
            ),
            _FieldSpec('source_label', 'Source label'),
          ], (payload) => widget.gateway.appendAssetMetric(record, payload)),
        );
      }
    } else if (widget.destination.route == '/operations/media') {
      add(
        'Complete upload',
        Icons.fact_check_outlined,
        () => _fieldPayloadAction('Complete media upload', const [
          _FieldSpec(
            'checksum',
            'SHA-256 checksum',
            helper: 'Must match the quarantined upload request.',
          ),
        ], (payload) => widget.gateway.completeMedia(record, payload)),
      );
      add(
        'Retire media',
        Icons.delete_outline,
        () => widget.gateway.retireMedia(record),
      );
    } else if (widget.destination.route == '/moderation') {
      add(
        'Open case',
        Icons.create_new_folder_outlined,
        () => widget.gateway.openModerationCase(record, const {
          'note': 'Opened from the staff dashboard.',
        }),
      );
      add(
        'Record decision',
        Icons.gavel_outlined,
        () => _fieldPayloadAction('Moderation decision', const [
          _FieldSpec(
            'status',
            'Decision status',
            options: ['investigating', 'resolved', 'dismissed'],
          ),
          _FieldSpec('resolution_code', 'Resolution code', required: false),
          _FieldSpec('reason', 'Reviewed reason'),
        ], (payload) => widget.gateway.decideModerationCase(record, payload)),
      );
    } else if (widget.destination.route == '/operations/privacy') {
      add(
        'Retry request',
        Icons.replay,
        () => widget.gateway.retryPrivacy(record),
      );
    } else if (widget.destination.route == '/operations/jobs') {
      add('Retry job', Icons.replay, () => widget.gateway.retryJob(record));
    }
    return Wrap(spacing: 12, runSpacing: 12, children: actions);
  }

  List<_FieldSpec> _catalogFields({bool forPatch = false}) {
    final fields = switch (widget.destination.route) {
      '/catalog/assets' => const [
        _FieldSpec('slug', 'Stable slug'),
        _FieldSpec('symbol', 'Display symbol'),
        _FieldSpec('name', 'Asset name'),
        _FieldSpec(
          'asset_type',
          'Asset type',
          options: ['equity', 'etf', 'index', 'cash'],
        ),
        _FieldSpec('currency', 'Currency', initial: 'USD'),
        _FieldSpec(
          'exchange',
          'Demo exchange',
          required: false,
          kind: _FieldKind.nullableText,
        ),
        _FieldSpec('status', 'Catalog status', options: ['active', 'inactive']),
      ],
      '/catalog/evidence' => const [
        _FieldSpec(
          'canonical_url',
          'Canonical HTTPS URL',
          helper: 'HTTPS links only.',
        ),
        _FieldSpec('title', 'Source title'),
        _FieldSpec('publisher', 'Publisher'),
        _FieldSpec(
          'published_at',
          'Published timestamp',
          required: false,
          kind: _FieldKind.nullableText,
        ),
        _FieldSpec('retrieved_at', 'Retrieved timestamp'),
        _FieldSpec(
          'source_kind',
          'Source kind',
          options: [
            'filing',
            'company',
            'exchange',
            'research',
            'news',
            'other',
          ],
        ),
        _FieldSpec('status', 'Evidence status', options: ['active', 'retired']),
      ],
      '/catalog/evidence-claims' => const [
        _FieldSpec('source_id', 'Evidence source ID'),
        _FieldSpec('claim_type', 'Claim type'),
        _FieldSpec('summary', 'Dated claim summary'),
        _FieldSpec(
          'observed_at',
          'Observed timestamp',
          required: false,
          kind: _FieldKind.nullableText,
        ),
        _FieldSpec('uncertainty', 'Uncertainty statement'),
        _FieldSpec(
          'status',
          'Claim status',
          options: ['active', 'superseded', 'withdrawn'],
        ),
      ],
      '/community/seeded-creators' => const [
        _FieldSpec('slug', 'Stable fictional creator slug'),
        _FieldSpec('display_name', 'Display name'),
        _FieldSpec('bio', 'Fictional creator biography'),
        _FieldSpec(
          'avatar_media_id',
          'Avatar media ID',
          required: false,
          kind: _FieldKind.nullableText,
        ),
        _FieldSpec('status', 'Creator status', options: ['active', 'retired']),
      ],
      _ => const <_FieldSpec>[],
    };
    if (!forPatch) return fields;
    return fields.where((field) => field.key != 'slug').toList(growable: false);
  }

  Future<void> _payloadAction(
    String title,
    Future<void> Function(Map<String, Object?> payload) action,
  ) async {
    final payload = await _promptJson(title, '{}');
    if (payload != null) await action(payload);
  }

  Future<void> _fieldPayloadAction(
    String title,
    List<_FieldSpec> fields,
    Future<void> Function(Map<String, Object?> payload) action,
  ) async {
    final payload = await _promptFields(title, fields);
    if (payload != null) await action(payload);
  }

  Future<void> _fieldAction(
    String title,
    List<_FieldSpec> fields,
    Future<void> Function(Map<String, Object?> payload) action,
  ) async {
    final payload = await _promptFields(title, fields);
    if (payload != null) {
      await _controller.runAction(() => action(payload));
    }
  }

  Future<Map<String, Object?>?> _promptFields(
    String title,
    List<_FieldSpec> fields,
  ) async {
    final formKey = GlobalKey<FormState>();
    final values = <String, String>{
      for (final field in fields)
        field.key: field.initial ?? field.options?.first ?? '',
    };
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 620,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final field in fields) ...[
                    if (field.options case final options?)
                      DropdownButtonFormField<String>(
                        initialValue: values[field.key],
                        decoration: InputDecoration(
                          labelText: field.label,
                          helperText: field.helper,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          for (final option in options)
                            DropdownMenuItem(
                              value: option,
                              child: Text(option),
                            ),
                        ],
                        onChanged: (value) => values[field.key] = value ?? '',
                      )
                    else
                      TextFormField(
                        initialValue: values[field.key],
                        decoration: InputDecoration(
                          labelText: field.label,
                          helperText: field.helper,
                          border: const OutlineInputBorder(),
                        ),
                        minLines: field.label.contains('summary') ? 3 : 1,
                        maxLines: field.label.contains('summary') ? 6 : 1,
                        onChanged: (value) => values[field.key] = value,
                        validator: (value) => _fieldError(field, value ?? ''),
                      ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (submitted != true) return null;
    return {
      for (final field in fields)
        if (values[field.key]!.trim().isNotEmpty ||
            field.kind == _FieldKind.nullableText ||
            field.kind == _FieldKind.nullableInteger)
          field.key: _fieldValue(field, values[field.key]!.trim()),
    };
  }

  String? _fieldError(_FieldSpec field, String raw) {
    final value = raw.trim();
    if (field.required && value.isEmpty) return '${field.label} is required.';
    if (value.isEmpty) return null;
    if (value.contains(RegExp(r'[<>\u0000]'))) {
      return 'Active markup is not allowed.';
    }
    if (field.key.contains('url') && !value.startsWith('https://')) {
      return 'Use an HTTPS URL.';
    }
    if (field.key == 'checksum' && !RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
      return 'Enter a 64-character lowercase SHA-256 checksum.';
    }
    if ((field.kind == _FieldKind.integer ||
            field.kind == _FieldKind.nullableInteger) &&
        int.tryParse(value) == null) {
      return 'Enter a whole number.';
    }
    return null;
  }

  Object? _fieldValue(_FieldSpec field, String value) => switch (field.kind) {
    _FieldKind.integer => int.parse(value),
    _FieldKind.nullableInteger => value.isEmpty ? null : int.parse(value),
    _FieldKind.nullableText => value.isEmpty ? null : value,
    _FieldKind.text => value,
  };

  Future<Map<String, Object?>?> _promptJson(
    String title,
    String template,
  ) async {
    final controller = TextEditingController(text: template);
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 620,
          child: TextField(
            controller: controller,
            minLines: 10,
            maxLines: 16,
            decoration: const InputDecoration(
              labelText: 'Schema-bound payload',
              helperText: 'The API applies strict domain validation and rejects unknown fields.',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (submitted != true) return null;
    final decoded = jsonDecode(controller.text);
    return decoded is Map<String, Object?> ? decoded : null;
  }

  Future<void> _verifyCoven() async {
    final payload = await _promptJson(
      'Verify a Coven qualification',
      '{"qualification_id":"00000000-0000-4000-8000-000000000000","evidence_claim_ids":["00000000-0000-4000-8000-000000000000"],"effective_as_of":"2026-08-24","decision":"verified","reason":"Independent evidence review completed."}',
    );
    if (payload == null) return;
    final qualificationId = payload.remove('qualification_id');
    if (qualificationId is! String) return;
    await widget.gateway.verifyCovenQualification(qualificationId, payload);
  }

  Future<void> _confirmPublish() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.destination.highTrust
              ? 'Confirm high-trust publication'
              : 'Confirm publication',
        ),
        content: const Text(
          'Publication is versioned and audited. A withdrawal will not rewrite historical member assignments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _controller.publish();
    }
  }

  Future<void> _showDraftEditor() async {
    final slug = TextEditingController();
    final payload = TextEditingController(text: '{\n  "title": ""\n}');
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('New ${widget.destination.title} draft'),
        content: SizedBox(
          width: 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: slug,
                decoration: const InputDecoration(labelText: 'Stable slug'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: payload,
                minLines: 10,
                maxLines: 16,
                decoration: const InputDecoration(
                  labelText: 'Typed JSON payload',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create draft'),
          ),
        ],
      ),
    );
    if (submitted != true) return;
    final value = jsonDecode(payload.text);
    if (value is Map<String, Object?>) {
      await _controller.createDraft(slug.text, value);
    }
  }
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

enum _FieldKind { text, integer, nullableInteger, nullableText }

class _FieldSpec {
  const _FieldSpec(
    this.key,
    this.label, {
    this.initial,
    this.helper,
    this.options,
    this.required = true,
    this.kind = _FieldKind.text,
  });

  final String key;
  final String label;
  final String? initial;
  final String? helper;
  final List<String>? options;
  final bool required;
  final _FieldKind kind;
}
