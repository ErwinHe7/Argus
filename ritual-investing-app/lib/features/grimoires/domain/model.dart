import 'package:flutter/foundation.dart';

import '../../discover/domain/model.dart';

enum GrimoireSavePhase {
  idle,
  saving,
  saved,
  reconciled,
  retryableFailure,
  terminalFailure,
}

@immutable
class GrimoireAssetReference {
  const GrimoireAssetReference({
    required this.id,
    required this.revisionId,
    required this.slug,
    required this.symbol,
    required this.name,
    required this.appearanceReason,
    required this.demo,
  });

  final String id;
  final String revisionId;
  final String slug;
  final String symbol;
  final String name;
  final String appearanceReason;
  final ResearchDemoDisclosure demo;
}

@immutable
class GrimoireDetail {
  GrimoireDetail({
    required this.id,
    required this.revisionId,
    required this.slug,
    required this.title,
    required this.description,
    required this.theme,
    required this.curatorLabel,
    required List<GrimoireAssetReference> assets,
    required this.saved,
    required this.demo,
  }) : assets = List.unmodifiable(assets);

  final String id;
  final String revisionId;
  final String slug;
  final String title;
  final String description;
  final String theme;
  final String curatorLabel;
  final List<GrimoireAssetReference> assets;
  final bool saved;
  final ResearchDemoDisclosure demo;

  GrimoireDetail copyWith({bool? saved}) => GrimoireDetail(
    id: id,
    revisionId: revisionId,
    slug: slug,
    title: title,
    description: description,
    theme: theme,
    curatorLabel: curatorLabel,
    assets: assets,
    saved: saved ?? this.saved,
    demo: demo,
  );
}
