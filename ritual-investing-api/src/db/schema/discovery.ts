import { sql } from "drizzle-orm";
import {
  boolean,
  foreignKey,
  index,
  integer,
  pgTable,
  text,
  timestamp,
  unique,
  uuid,
} from "drizzle-orm/pg-core";

import {
  assets,
  covenEntries,
  covenVerifications,
  editorialItems,
  editorialRevisions,
  mediaAssets,
} from "./editorial";
import { tenants } from "./identity";

export const grimoires = pgTable("grimoires", {
  id: uuid("id").defaultRandom().primaryKey(),
  editorialItemId: uuid("editorial_item_id")
    .notNull()
    .unique()
    .references(() => editorialItems.id),
  themeCode: text("theme_code").notNull(),
});

export const grimoireRevisions = pgTable("grimoire_revisions", {
  revisionId: uuid("revision_id")
    .primaryKey()
    .references(() => editorialRevisions.id),
  title: text("title").notNull(),
  description: text("description").notNull(),
  curatorLabel: text("curator_label").notNull(),
  artMediaId: uuid("art_media_id").references(() => mediaAssets.id),
});

export const grimoireRevisionAssets = pgTable(
  "grimoire_revision_assets",
  {
    revisionId: uuid("revision_id")
      .notNull()
      .references(() => grimoireRevisions.revisionId),
    assetId: uuid("asset_id")
      .notNull()
      .references(() => assets.id),
    ordinal: integer("ordinal").notNull(),
    note: text("note"),
  },
  (table) => [
    unique("grimoire_revision_assets_revision_asset_unique").on(
      table.revisionId,
      table.assetId,
    ),
    unique("grimoire_revision_assets_revision_ordinal_unique").on(
      table.revisionId,
      table.ordinal,
    ),
  ],
);

export const seededCreators = pgTable("seeded_creators", {
  id: uuid("id").defaultRandom().primaryKey(),
  slug: text("slug").notNull().unique(),
  displayName: text("display_name").notNull(),
  bio: text("bio").notNull(),
  avatarMediaId: uuid("avatar_media_id").references(() => mediaAssets.id),
  isFictional: boolean("is_fictional").notNull().default(true),
  status: text("status").notNull(),
  version: integer("version").notNull().default(1),
});

export const circleTemplates = pgTable("circle_templates", {
  id: uuid("id").defaultRandom().primaryKey(),
  editorialItemId: uuid("editorial_item_id")
    .notNull()
    .unique()
    .references(() => editorialItems.id),
  creatorId: uuid("creator_id")
    .notNull()
    .references(() => seededCreators.id),
  themeCode: text("theme_code").notNull(),
});

export const circleTemplateRevisions = pgTable("circle_template_revisions", {
  revisionId: uuid("revision_id")
    .primaryKey()
    .references(() => editorialRevisions.id),
  title: text("title").notNull(),
  description: text("description").notNull(),
  artMediaId: uuid("art_media_id").references(() => mediaAssets.id),
});

export const circleTemplateAssets = pgTable(
  "circle_template_assets",
  {
    revisionId: uuid("revision_id")
      .notNull()
      .references(() => circleTemplateRevisions.revisionId),
    assetId: uuid("asset_id")
      .notNull()
      .references(() => assets.id),
    ordinal: integer("ordinal").notNull(),
    weightBps: integer("weight_bps"),
    note: text("note"),
  },
  (table) => [
    unique("circle_template_assets_revision_asset_unique").on(
      table.revisionId,
      table.assetId,
    ),
  ],
);

export const circles = pgTable(
  "circles",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    tenantId: uuid("tenant_id")
      .notNull()
      .references(() => tenants.id, { onDelete: "cascade" }),
    title: text("title").notNull(),
    description: text("description").notNull(),
    sourceTemplateId: uuid("source_template_id").references(
      () => circleTemplates.id,
    ),
    sourceRevisionId: uuid("source_revision_id").references(
      () => editorialRevisions.id,
    ),
    version: integer("version").notNull().default(1),
    archivedAt: timestamp("archived_at", { withTimezone: true }),
  },
  (table) => [
    unique("circles_tenant_id_id_unique").on(table.tenantId, table.id),
  ],
);

export const circleAssets = pgTable(
  "circle_assets",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    tenantId: uuid("tenant_id")
      .notNull()
      .references(() => tenants.id, { onDelete: "cascade" }),
    circleId: uuid("circle_id").notNull(),
    assetId: uuid("asset_id")
      .notNull()
      .references(() => assets.id),
    ordinal: integer("ordinal").notNull(),
    weightBps: integer("weight_bps"),
    note: text("note"),
  },
  (table) => [
    foreignKey({
      name: "circle_assets_tenant_circle_fk",
      columns: [table.tenantId, table.circleId],
      foreignColumns: [circles.tenantId, circles.id],
    }).onDelete("cascade"),
    unique("circle_assets_tenant_circle_asset_unique").on(
      table.tenantId,
      table.circleId,
      table.assetId,
    ),
    unique("circle_assets_tenant_circle_ordinal_unique").on(
      table.tenantId,
      table.circleId,
      table.ordinal,
    ),
  ],
);

export const savedAssets = pgTable(
  "saved_assets",
  {
    tenantId: uuid("tenant_id")
      .notNull()
      .references(() => tenants.id, { onDelete: "cascade" }),
    assetId: uuid("asset_id")
      .notNull()
      .references(() => assets.id),
    revisionId: uuid("revision_id").references(() => editorialRevisions.id),
    sourceKind: text("source_kind").notNull(),
    sourceId: uuid("source_id"),
    savedAt: timestamp("saved_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (table) => [
    unique("saved_assets_tenant_asset_unique").on(
      table.tenantId,
      table.assetId,
    ),
    index("saved_assets_revision_idx")
      .on(table.revisionId)
      .where(sql`${table.revisionId} is not null`),
  ],
);

export const savedGrimoires = pgTable(
  "saved_grimoires",
  {
    tenantId: uuid("tenant_id")
      .notNull()
      .references(() => tenants.id, { onDelete: "cascade" }),
    grimoireId: uuid("grimoire_id")
      .notNull()
      .references(() => grimoires.id),
    revisionId: uuid("revision_id")
      .notNull()
      .references(() => editorialRevisions.id),
    savedAt: timestamp("saved_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (table) => [
    unique("saved_grimoires_tenant_grimoire_unique").on(
      table.tenantId,
      table.grimoireId,
    ),
  ],
);

export const savedCircleTemplates = pgTable(
  "saved_circle_templates",
  {
    tenantId: uuid("tenant_id")
      .notNull()
      .references(() => tenants.id, { onDelete: "cascade" }),
    templateId: uuid("template_id")
      .notNull()
      .references(() => circleTemplates.id),
    revisionId: uuid("revision_id")
      .notNull()
      .references(() => editorialRevisions.id),
    savedAt: timestamp("saved_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (table) => [
    unique("saved_circle_templates_tenant_template_unique").on(
      table.tenantId,
      table.templateId,
    ),
  ],
);

export const savedCovenEntries = pgTable(
  "saved_coven_entries",
  {
    tenantId: uuid("tenant_id")
      .notNull()
      .references(() => tenants.id, { onDelete: "cascade" }),
    entryId: uuid("entry_id")
      .notNull()
      .references(() => covenEntries.id),
    verificationId: uuid("verification_id")
      .notNull()
      .references(() => covenVerifications.id),
    savedAt: timestamp("saved_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (table) => [
    unique("saved_coven_entries_tenant_entry_unique").on(
      table.tenantId,
      table.entryId,
    ),
  ],
);

export const memberIdempotencyRecords = pgTable(
  "member_idempotency_records",
  {
    tenantId: uuid("tenant_id")
      .notNull()
      .references(() => tenants.id, { onDelete: "cascade" }),
    operation: text("operation").notNull(),
    key: text("key").notNull(),
    requestHash: text("request_hash").notNull(),
    resourceId: uuid("resource_id"),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
    expiresAt: timestamp("expires_at", { withTimezone: true })
      .notNull()
      .default(sql`now() + interval '24 hours'`),
  },
  (table) => [
    unique("member_idempotency_scope_unique").on(
      table.tenantId,
      table.operation,
      table.key,
    ),
  ],
);
