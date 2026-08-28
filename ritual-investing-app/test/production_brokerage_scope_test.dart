import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('U8 adds Webull reads without removing U9-owned feature wiring', () {
    final source = File(
      'lib/core/bootstrap/production_member_feature_scope_factory.dart',
    ).readAsStringSync();

    expect(source, contains('brokerageConnectionController:'));
    expect(source, contains('brokeragePortfolioController:'));
    expect(source, contains('intentionController: intentionController'));
    expect(source, contains('futureMirrorController: futureMirrorController'));
  });
}
