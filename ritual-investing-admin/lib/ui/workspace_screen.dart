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
            kind: _FieldKind.checksum,
          ),
        ], widget.gateway.createMediaUpload),
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload request'),
      );
    }
    if (widget.destination.route == '/catalog/schedules') {
      return FilledButton.icon(
        onPressed: () => _fieldAction('Create ritual schedule', const [
          _FieldSpec(
            'local_date',
            'Local date',
            helper: 'YYYY-MM-DD',
            kind: _FieldKind.date,
          ),
          _FieldSpec('mode', 'Ritual mode', options: ['tarot', 'astrology']),
          _FieldSpec(
            'revision_id',
            'Approved revision ID',
            kind: _FieldKind.uuid,
          ),
          _FieldSpec('audience', 'Audience', options: ['member', 'public']),
          _FieldSpec(
            'effective_at',
            'Effective timestamp',
            helper: 'ISO-8601 timestamp with timezone.',
            kind: _FieldKind.timestamp,
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
        () => _editorialPayloadAction(
          'Create revision payload',
          record,
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
        () => _editorialPayloadAction(
          'Edit typed draft payload',
          record,
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
            AdminReviewDecision.approved,
          ),
        );
        add(
          'Request changes',
          Icons.change_circle_outlined,
          () => widget.gateway.decideReview(
            widget.destination,
            record,
            AdminReviewDecision.changesRequested,
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
          _FieldSpec(
            'revision_id',
            'Approved revision ID',
            kind: _FieldKind.uuid,
          ),
          _FieldSpec(
            'effective_at',
            'Effective timestamp',
            helper: 'ISO-8601 timestamp with timezone.',
            kind: _FieldKind.timestamp,
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
            _FieldSpec(
              'observed_at',
              'Observed timestamp',
              kind: _FieldKind.timestamp,
            ),
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
            kind: _FieldKind.checksum,
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
          kind: _FieldKind.httpsUrl,
        ),
        _FieldSpec('title', 'Source title'),
        _FieldSpec('publisher', 'Publisher'),
        _FieldSpec(
          'published_at',
          'Published timestamp',
          required: false,
          kind: _FieldKind.nullableTimestamp,
        ),
        _FieldSpec(
          'retrieved_at',
          'Retrieved timestamp',
          kind: _FieldKind.timestamp,
        ),
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
        _FieldSpec('source_id', 'Evidence source ID', kind: _FieldKind.uuid),
        _FieldSpec('claim_type', 'Claim type'),
        _FieldSpec('summary', 'Dated claim summary'),
        _FieldSpec(
          'observed_at',
          'Observed timestamp',
          required: false,
          kind: _FieldKind.nullableTimestamp,
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
          kind: _FieldKind.uuid,
        ),
        _FieldSpec('status', 'Creator status', options: ['active', 'retired']),
      ],
      _ => const <_FieldSpec>[],
    };
    if (!forPatch) return fields;
    return fields.where((field) => field.key != 'slug').toList(growable: false);
  }

  Future<void> _editorialPayloadAction(
    String title,
    AdminRecord record,
    Future<void> Function(Map<String, Object?> payload) action,
  ) async {
    final current =
        (await widget.gateway.getEditorial(record)).payload ??
        const <String, Object?>{};
    final payload = await _promptFields(
      title,
      _editorialFields(),
      initialValues: current,
    );
    if (payload != null) {
      await action(_editorialPayload({...current, ...payload}));
    }
  }

  Map<String, Object?> _editorialPayload(Map<String, Object?> fields) {
    final payload = Map<String, Object?>.from(fields);
    if (_editorialKind == _EditorialKind.assetCodex) {
      final risk = <String, Object?>{};
      for (final key in ['risk_title', 'risk_detail', 'risk_severity']) {
        final value = payload.remove(key);
        if (value != null) risk[key.substring(5)] = value;
      }
      if (risk.isNotEmpty) {
        payload['risks'] = [...(payload['risks'] as List? ?? const []), risk];
      }
      final metric = <String, Object?>{};
      for (final key in [
        'metric_observed_at',
        'metric_price_minor',
        'metric_change_bps',
        'metric_expense_ratio_bps',
        'metric_source_label',
      ]) {
        final value = payload.remove(key);
        if (value != null) metric[key.substring(7)] = value;
      }
      if (metric.isNotEmpty) {
        payload['metrics'] = [
          ...(payload['metrics'] as List? ?? const []),
          metric,
        ];
      }
      return payload;
    }
    if (_editorialKind != _EditorialKind.coven) return payload;
    final qualification = <String, Object?>{};
    for (final key in [
      'criterion_code',
      'person_name',
      'claim',
      'evidence_claim_id',
      'valid_to',
    ]) {
      final value = payload.remove(key);
      if (value != null) qualification[key] = value;
    }
    payload['qualifications'] = [qualification];
    return payload;
  }

  List<_FieldSpec> _editorialFields() => switch (_editorialKind) {
    _EditorialKind.ritual => const [
      _FieldSpec('scenario_key', 'Scenario key'),
      _FieldSpec('mode', 'Mode', options: ['tarot', 'astrology']),
      _FieldSpec('cadence', 'Cadence'),
      _FieldSpec('title', 'Title'),
      _FieldSpec('interpretation', 'Interpretation', multiline: true),
      _FieldSpec('guidance', 'Guidance', multiline: true),
      _FieldSpec('market_label', 'Market label'),
      _FieldSpec(
        'observation_at',
        'Observation timestamp',
        kind: _FieldKind.timestamp,
      ),
      _FieldSpec('uncertainty', 'Uncertainty statement', multiline: true),
      _FieldSpec(
        'idea_asset_ids',
        'Idea asset IDs',
        helper: 'Enter 3–5 UUIDs separated by commas.',
        kind: _FieldKind.uuidList,
        minItems: 3,
        maxItems: 5,
      ),
      _FieldSpec(
        'evidence_claim_ids',
        'Evidence claim IDs',
        helper: 'Enter one or more UUIDs separated by commas.',
        kind: _FieldKind.uuidList,
        minItems: 1,
        maxItems: 100,
      ),
    ],
    _EditorialKind.assetCodex => const [
      _FieldSpec(
        'asset_id',
        'Asset ID',
        required: false,
        kind: _FieldKind.uuid,
      ),
      _FieldSpec('appearance_reason', 'Appearance reason', multiline: true),
      _FieldSpec('thesis', 'Editorial thesis', multiline: true),
      _FieldSpec('limitations', 'Limitations', multiline: true),
      _FieldSpec(
        'metrics_as_of',
        'Metrics timestamp',
        kind: _FieldKind.timestamp,
      ),
      _FieldSpec(
        'evidence_claim_ids',
        'Evidence claim IDs',
        helper: 'Enter UUIDs separated by commas.',
        kind: _FieldKind.uuidList,
        required: false,
        maxItems: 100,
      ),
      _FieldSpec('risk_title', 'Add risk title', required: false),
      _FieldSpec(
        'risk_detail',
        'Add risk detail',
        required: false,
        multiline: true,
      ),
      _FieldSpec(
        'risk_severity',
        'Add risk severity',
        required: false,
        helper: 'low, medium, or high',
      ),
      _FieldSpec(
        'metric_observed_at',
        'Add metric observed timestamp',
        required: false,
        kind: _FieldKind.nullableTimestamp,
      ),
      _FieldSpec(
        'metric_price_minor',
        'Add metric price (minor units)',
        required: false,
        kind: _FieldKind.nullableInteger,
      ),
      _FieldSpec(
        'metric_change_bps',
        'Add metric change (basis points)',
        required: false,
        kind: _FieldKind.nullableInteger,
      ),
      _FieldSpec(
        'metric_expense_ratio_bps',
        'Add metric expense ratio (basis points)',
        required: false,
        kind: _FieldKind.nullableInteger,
      ),
      _FieldSpec(
        'metric_source_label',
        'Add metric source label',
        required: false,
      ),
    ],
    _EditorialKind.coven => const [
      _FieldSpec('company_id', 'Company ID', kind: _FieldKind.uuid),
      _FieldSpec(
        'category',
        'Category',
        options: ['founder', 'owner', 'chief_executive'],
      ),
      _FieldSpec('focus', 'Research focus', multiline: true),
      _FieldSpec('teaser', 'Teaser', multiline: true),
      _FieldSpec('summary', 'Summary', multiline: true),
      _FieldSpec('inclusion_rationale', 'Inclusion rationale', multiline: true),
      _FieldSpec('limitations', 'Limitations', multiline: true),
      _FieldSpec(
        'effective_date',
        'Effective date',
        helper: 'YYYY-MM-DD',
        kind: _FieldKind.date,
      ),
      _FieldSpec(
        'verified_as_of',
        'Verified as of',
        helper: 'YYYY-MM-DD',
        kind: _FieldKind.date,
      ),
      _FieldSpec('criterion_code', 'Qualification criterion code'),
      _FieldSpec('person_name', 'Qualified person name'),
      _FieldSpec('claim', 'Qualification claim', multiline: true),
      _FieldSpec(
        'evidence_claim_id',
        'Qualification evidence claim ID',
        required: false,
        kind: _FieldKind.uuid,
      ),
      _FieldSpec(
        'valid_to',
        'Qualification valid to',
        helper: 'YYYY-MM-DD, or leave blank when current.',
        required: false,
        kind: _FieldKind.nullableDate,
      ),
    ],
    _EditorialKind.grimoire => const [
      _FieldSpec('theme_code', 'Theme code'),
      _FieldSpec('title', 'Title'),
      _FieldSpec('description', 'Description', multiline: true),
      _FieldSpec('theme', 'Display theme'),
      _FieldSpec('curator_label', 'Curator label'),
      _FieldSpec(
        'asset_ids',
        'Asset IDs',
        helper: 'Enter UUIDs separated by commas.',
        kind: _FieldKind.uuidList,
        required: false,
        maxItems: 100,
      ),
    ],
    _EditorialKind.circleTemplate => const [
      _FieldSpec('creator_label', 'Creator label'),
      _FieldSpec('title', 'Title'),
      _FieldSpec('description', 'Description', multiline: true),
      _FieldSpec('theme', 'Theme'),
      _FieldSpec('creator_slug', 'Creator slug'),
      _FieldSpec('creator_bio', 'Creator biography', multiline: true),
      _FieldSpec(
        'asset_ids',
        'Asset IDs',
        helper: 'Enter UUIDs separated by commas.',
        kind: _FieldKind.uuidList,
        required: false,
        maxItems: 50,
      ),
    ],
    _EditorialKind.rowan => const [
      _FieldSpec('script_key', 'Script key'),
      _FieldSpec('surface', 'Surface'),
      _FieldSpec('body_template', 'Body template', multiline: true),
      _FieldSpec('risk_footer', 'Risk footer', multiline: true),
      _FieldSpec(
        'allowed_tokens',
        'Allowed tokens',
        helper: 'Enter tokens separated by commas.',
        kind: _FieldKind.stringList,
        minItems: 1,
      ),
    ],
    _EditorialKind.briefingTemplate => const [
      _FieldSpec('title', 'Title'),
      _FieldSpec('summary', 'Summary', multiline: true),
      _FieldSpec('disclosure', 'Disclosure', multiline: true),
    ],
    null => const <_FieldSpec>[],
  };

  _EditorialKind? get _editorialKind =>
      switch (widget.destination.editorialKind) {
        'ritual' => _EditorialKind.ritual,
        'asset_codex' => _EditorialKind.assetCodex,
        'coven' => _EditorialKind.coven,
        'grimoire' => _EditorialKind.grimoire,
        'circle_template' => _EditorialKind.circleTemplate,
        'rowan' => _EditorialKind.rowan,
        'briefing_template' => _EditorialKind.briefingTemplate,
        _ => null,
      };

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
    List<_FieldSpec> fields, {
    Map<String, Object?> initialValues = const {},
  }) async {
    final formKey = GlobalKey<FormState>();
    final values = <String, String>{
      for (final field in fields)
        field.key: _initialText(field, initialValues[field.key]),
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
                        minLines: field.multiline ? 3 : 1,
                        maxLines: field.multiline ? 8 : 1,
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
            field.kind == _FieldKind.nullableInteger ||
            field.kind == _FieldKind.nullableTimestamp ||
            field.kind == _FieldKind.nullableDate)
          field.key: _fieldValue(field, values[field.key]!.trim()),
    };
  }

  String _initialText(_FieldSpec field, Object? value) => value is List
      ? value.join(', ')
      : value?.toString() ?? field.initial ?? field.options?.first ?? '';

  String? _fieldError(_FieldSpec field, String raw) {
    final value = raw.trim();
    if (field.required && value.isEmpty) return '${field.label} is required.';
    if (value.isEmpty) return null;
    if (value.contains(RegExp(r'[<>\u0000]'))) {
      return 'Active markup is not allowed.';
    }
    if (field.kind == _FieldKind.httpsUrl && !value.startsWith('https://')) {
      return 'Use an HTTPS URL.';
    }
    if (field.kind == _FieldKind.checksum &&
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
      return 'Enter a 64-character lowercase SHA-256 checksum.';
    }
    if (field.kind == _FieldKind.uuid && !_uuidPattern.hasMatch(value)) {
      return 'Enter a valid UUID.';
    }
    if ((field.kind == _FieldKind.integer ||
            field.kind == _FieldKind.nullableInteger) &&
        int.tryParse(value) == null) {
      return 'Enter a whole number.';
    }
    if (field.kind == _FieldKind.stringList ||
        field.kind == _FieldKind.uuidList) {
      final items = _stringList(value);
      if (field.minItems case final minimum? when items.length < minimum) {
        return 'Enter at least $minimum values.';
      }
      if (field.maxItems case final maximum? when items.length > maximum) {
        return 'Enter no more than $maximum values.';
      }
      if (field.kind == _FieldKind.uuidList &&
          items.any((item) => !_uuidPattern.hasMatch(item))) {
        return 'Enter valid UUIDs separated by commas.';
      }
    }
    if ((field.kind == _FieldKind.date ||
            field.kind == _FieldKind.nullableDate) &&
        !_isIsoDate(value)) {
      return 'Use YYYY-MM-DD.';
    }
    if ((field.kind == _FieldKind.timestamp ||
            field.kind == _FieldKind.nullableTimestamp) &&
        (!RegExp(r'(?:Z|[+-]\d{2}:\d{2})$').hasMatch(value) ||
            DateTime.tryParse(value) == null)) {
      return 'Use an ISO-8601 timestamp with timezone.';
    }
    return null;
  }

  List<String> _stringList(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  bool _isIsoDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    final parsed = DateTime.tryParse(value);
    return parsed != null &&
        parsed.year == int.parse(value.substring(0, 4)) &&
        parsed.month == int.parse(value.substring(5, 7)) &&
        parsed.day == int.parse(value.substring(8, 10));
  }

  Object? _fieldValue(_FieldSpec field, String value) => switch (field.kind) {
    _FieldKind.integer => int.parse(value),
    _FieldKind.nullableInteger => value.isEmpty ? null : int.parse(value),
    _FieldKind.nullableText => value.isEmpty ? null : value,
    _FieldKind.nullableTimestamp => value.isEmpty ? null : value,
    _FieldKind.nullableDate => value.isEmpty ? null : value,
    _FieldKind.stringList || _FieldKind.uuidList => _stringList(value),
    _FieldKind.text ||
    _FieldKind.uuid ||
    _FieldKind.httpsUrl ||
    _FieldKind.checksum ||
    _FieldKind.date ||
    _FieldKind.timestamp => value,
  };

  Future<void> _verifyCoven() async {
    final payload = await _promptFields('Verify a Coven qualification', const [
      _FieldSpec('qualification_id', 'Qualification ID', kind: _FieldKind.uuid),
      _FieldSpec(
        'evidence_claim_ids',
        'Evidence claim IDs',
        helper: 'Enter one or more UUIDs separated by commas.',
        kind: _FieldKind.uuidList,
        minItems: 1,
      ),
      _FieldSpec(
        'effective_as_of',
        'Effective as of',
        helper: 'YYYY-MM-DD',
        kind: _FieldKind.date,
      ),
      _FieldSpec('decision', 'Decision', options: ['verified', 'rejected']),
      _FieldSpec('reason', 'Reason', multiline: true),
    ]);
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
    final payload = await _promptFields(
      'New ${widget.destination.title} draft',
      [const _FieldSpec('slug', 'Stable slug'), ..._editorialFields()],
    );
    if (payload == null) return;
    final slug = payload.remove('slug');
    if (slug is String) {
      await _controller.createDraft(slug, _editorialPayload(payload));
    }
  }
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

enum _EditorialKind {
  ritual,
  assetCodex,
  coven,
  grimoire,
  circleTemplate,
  rowan,
  briefingTemplate,
}

enum _FieldKind {
  text,
  integer,
  nullableInteger,
  nullableText,
  stringList,
  uuid,
  uuidList,
  httpsUrl,
  checksum,
  date,
  timestamp,
  nullableTimestamp,
  nullableDate,
}

class _FieldSpec {
  const _FieldSpec(
    this.key,
    this.label, {
    this.initial,
    this.helper,
    this.options,
    this.required = true,
    this.kind = _FieldKind.text,
    this.multiline = false,
    this.minItems,
    this.maxItems,
  });

  final String key;
  final String label;
  final String? initial;
  final String? helper;
  final List<String>? options;
  final bool required;
  final _FieldKind kind;
  final bool multiline;
  final int? minItems;
  final int? maxItems;
}
