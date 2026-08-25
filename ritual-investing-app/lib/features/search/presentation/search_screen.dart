import 'package:flutter/material.dart' hide SearchController;

import '../../../core/api/state_status.dart';
import '../../../core/api/view_state.dart';
import '../../../core/presentation/demo_disclosure.dart';
import '../application/controller.dart';
import '../domain/model.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.controller,
    required this.onOpenAsset,
  });

  final SearchController controller;
  final ValueChanged<String> onOpenAsset;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late SearchController _controller;
  late final TextEditingController _queryController;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _queryController = TextEditingController(text: _controller.context.query);
    _controller.addListener(_synchronizeQuery);
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    _controller.removeListener(_synchronizeQuery);
    _controller = widget.controller;
    _controller.addListener(_synchronizeQuery);
    _synchronizeQuery();
  }

  void _synchronizeQuery() {
    final authoritative = _controller.context.query;
    if (_queryController.text == authoritative) return;
    _queryController.value = TextEditingValue(
      text: authoritative,
      selection: TextSelection.collapsed(offset: authoritative.length),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_synchronizeQuery);
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Search the Codex')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            TextField(
              key: const Key('codex-search-field'),
              controller: _queryController,
              onChanged: _controller.updateQuery,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Search published Demo research',
                helperText: 'Enter at least 2 characters',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final kind in SearchKind.values)
                  FilterChip(
                    label: Text(_kindLabel(kind)),
                    selected: _controller.context.kinds.contains(kind),
                    onSelected: (selected) {
                      final next = Set<SearchKind>.of(
                        _controller.context.kinds,
                      );
                      selected ? next.add(kind) : next.remove(kind);
                      _controller.updateKinds(next);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            StateStatus(
              phase: _controller.state.phase,
              onRetry: _controller.retry,
            ),
            if (_controller.state.phase == LoadPhase.throttled)
              Text(
                'Search can retry in ${_controller.retryAfter?.inSeconds ?? 30} seconds.',
              ),
            for (final item
                in _controller.state.value?.items ?? const <SearchItem>[])
              ListTile(
                contentPadding: EdgeInsets.zero,
                minTileHeight: 56,
                onTap: item.kind == SearchKind.asset
                    ? () => widget.onOpenAsset(item.id)
                    : null,
                leading: item.isDemo
                    ? const DemoBadge(horizontalPadding: 7)
                    : null,
                title: Text(
                  item.symbol == null
                      ? item.title
                      : '${item.symbol} · ${item.title}',
                ),
                subtitle: Text(
                  '${item.subtitle}\n${_kindLabel(item.kind)} · revision ${item.revisionId}',
                ),
                trailing: item.kind == SearchKind.asset
                    ? const Icon(Icons.chevron_right)
                    : null,
              ),
            if (_controller.state.value?.hasMore == true)
              OutlinedButton(
                key: const Key('search-load-more'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                onPressed: _controller.loadingMore
                    ? null
                    : _controller.loadMore,
                child: Text(_controller.loadingMore ? 'Loading…' : 'Load more'),
              ),
          ],
        ),
      ),
    ),
  );
}

String _kindLabel(SearchKind kind) => switch (kind) {
  SearchKind.asset => 'Assets',
  SearchKind.coven => 'Coven',
  SearchKind.grimoire => 'Grimoires',
  SearchKind.circleTemplate => 'Circles',
};
