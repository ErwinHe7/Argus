// ignore_for_file: prefer_initializing_formals

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/admin_gateway.dart';
import '../domain/admin_models.dart';

class WorkspaceController extends ChangeNotifier {
  // The public named argument stays `gateway`; the stored dependency is private.
  WorkspaceController({
    required this.destination,
    required AdminGateway gateway,
  }) : _gateway = gateway;
  final AdminDestination destination;
  final AdminGateway _gateway;
  List<AdminRecord> _records = const [];
  AdminRecord? _selected;
  bool _loading = false;
  String? _error;

  List<AdminRecord> get records => _records;
  AdminRecord? get selected => _selected;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _records = await _gateway.list(destination);
    } catch (_) {
      _error = 'This workspace could not be loaded.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void select(AdminRecord record) {
    _selected = record;
    notifyListeners();
  }

  Future<void> requestReview() async {
    final record = _selected;
    if (record == null) return;
    await runAction(() => _gateway.requestReview(destination, record));
  }

  Future<void> publish() async {
    final record = _selected;
    if (record == null) return;
    await runAction(() => _gateway.publish(destination, record));
  }

  Future<void> createDraft(String slug, Map<String, Object?> payload) async {
    await runAction(() => _gateway.createDraft(destination, slug, payload));
  }

  Future<void> runAction(Future<void> Function() action) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      _records = await _gateway.list(destination);
      _selected = _recordWithId(_selected?.id);
    } catch (error) {
      _error = error is DioException && error.response?.statusCode == 409
          ? 'This record changed. Refresh before retrying the transition.'
          : 'The reviewed transition could not be applied.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  AdminRecord? _recordWithId(String? id) {
    if (id == null) return null;
    for (final record in _records) {
      if (record.id == id) return record;
    }
    return null;
  }
}
