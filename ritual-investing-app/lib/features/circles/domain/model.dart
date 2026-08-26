import 'package:flutter/foundation.dart';

import '../../discover/domain/model.dart';

enum CircleMutationPhase {
  idle,
  committing,
  committed,
  conflictReview,
  retryableFailure,
  terminalFailure,
}

enum CircleTemplateSavePhase {
  idle,
  saving,
  saved,
  reconciled,
  retryableFailure,
  terminalFailure,
}

@immutable
class CircleAsset {
  const CircleAsset({
    required this.assetId,
    required this.ordinal,
    required this.note,
    required this.weightBps,
  });

  final String assetId;
  final int ordinal;
  final String? note;
  final int? weightBps;

  CircleAsset copyWith({int? ordinal, String? note, int? weightBps}) =>
      CircleAsset(
        assetId: assetId,
        ordinal: ordinal ?? this.ordinal,
        note: note ?? this.note,
        weightBps: weightBps ?? this.weightBps,
      );
}

@immutable
class PrivateCircle {
  PrivateCircle({
    required this.id,
    required this.title,
    required this.description,
    required this.private,
    required this.version,
    required List<CircleAsset> assets,
    required this.sourceTemplateId,
    required this.sourceRevisionId,
    required this.archivedAt,
  }) : assets = List.unmodifiable(assets);

  final String id;
  final String title;
  final String description;
  final bool private;
  final int version;
  final List<CircleAsset> assets;
  final String? sourceTemplateId;
  final String? sourceRevisionId;
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;
}

@immutable
class CircleCollection {
  CircleCollection({
    required List<PrivateCircle> items,
    required this.nextCursor,
    required this.hasMore,
  }) : items = List.unmodifiable(items);

  final List<PrivateCircle> items;
  final String? nextCursor;
  final bool hasMore;
}

@immutable
class CircleDraft {
  CircleDraft({
    required this.title,
    required this.description,
    required List<CircleAsset> assets,
  }) : assets = List.unmodifiable(assets);

  factory CircleDraft.fromCircle(PrivateCircle value) => CircleDraft(
    title: value.title,
    description: value.description,
    assets: value.assets,
  );

  final String title;
  final String description;
  final List<CircleAsset> assets;

  CircleDraft copyWith({
    String? title,
    String? description,
    List<CircleAsset>? assets,
  }) => CircleDraft(
    title: title ?? this.title,
    description: description ?? this.description,
    assets: assets ?? this.assets,
  );
}

@immutable
class CircleCreateCommand {
  CircleCreateCommand({
    required this.idempotencyKey,
    required this.title,
    required this.description,
    required List<CircleAsset> assets,
  }) : assets = List.unmodifiable(assets);

  final String idempotencyKey;
  final String title;
  final String description;
  final List<CircleAsset> assets;
}

@immutable
class CircleCopyCommand {
  const CircleCopyCommand({
    required this.idempotencyKey,
    required this.templateId,
    required this.title,
  });

  final String idempotencyKey;
  final String templateId;
  final String? title;
}

@immutable
class CircleTemplateAsset {
  const CircleTemplateAsset({
    required this.id,
    required this.revisionId,
    required this.slug,
    required this.symbol,
    required this.name,
    required this.appearanceReason,
    required this.note,
    required this.ordinal,
    required this.weightBps,
    required this.demo,
  });

  final String id;
  final String revisionId;
  final String slug;
  final String symbol;
  final String name;
  final String appearanceReason;
  final String? note;
  final int ordinal;
  final int? weightBps;
  final ResearchDemoDisclosure demo;
}

@immutable
class CircleTemplateDetail {
  CircleTemplateDetail({
    required this.id,
    required this.revisionId,
    required this.slug,
    required this.title,
    required this.description,
    required this.theme,
    required this.creator,
    required List<CircleTemplateAsset> assets,
    required this.saved,
    required this.demo,
  }) : assets = List.unmodifiable(assets);

  final String id;
  final String revisionId;
  final String slug;
  final String title;
  final String description;
  final String theme;
  final SeededCreatorView creator;
  final List<CircleTemplateAsset> assets;
  final bool saved;
  final ResearchDemoDisclosure demo;

  CircleTemplateDetail copyWith({bool? saved}) => CircleTemplateDetail(
    id: id,
    revisionId: revisionId,
    slug: slug,
    title: title,
    description: description,
    theme: theme,
    creator: creator,
    assets: assets,
    saved: saved ?? this.saved,
    demo: demo,
  );
}
