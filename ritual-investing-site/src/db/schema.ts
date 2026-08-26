import { check, pgSchema, text, timestamp } from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";

export const waitlistPrivate = pgSchema("waitlist_private");

export const provisionalSubmissions = waitlistPrivate.table(
  "provisional_submissions",
  {
    normalizedEmail: text("normalized_email").primaryKey(),
    noticeVersion: text("notice_version").notNull(),
    submittedAt: timestamp("submitted_at", { withTimezone: true, mode: "date" })
      .notNull()
      .default(sql`clock_timestamp()`),
  },
  (table) => [
    check(
      "provisional_submissions_normalized_email_check",
      sql`${table.normalizedEmail} = lower(btrim(${table.normalizedEmail})) and char_length(${table.normalizedEmail}) between 3 and 254 and ${table.normalizedEmail} ~ '^[^[:space:]@]+@[^[:space:]@]+$'`,
    ),
    check(
      "provisional_submissions_notice_version_check",
      sql`char_length(${table.noticeVersion}) between 1 and 128 and ${table.noticeVersion} ~ '^[a-z0-9][a-z0-9-]*$'`,
    ),
  ],
);

export type ProvisionalSubmission = typeof provisionalSubmissions.$inferSelect;
