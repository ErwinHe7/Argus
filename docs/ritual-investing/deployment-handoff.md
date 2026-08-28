# Supabase deployment handoff

The implementation and operator authority are documented in:

- [Supabase operations](supabase-operations-runbook.md) for local PR stacks,
  guarded hosted-development promotion, secrets, rollback, and inventory;
- [Cloudflare Pages](cloudflare-runbook.md) for the static public site and Demo;
- [Webull operations](webull-operations-runbook.md) for provider fences,
  recovery, disconnection, and rotation; and
- [production launch gates](production-launch-gates.md) for unresolved hosting,
  SMTP, backup, monitoring, quota, and provider decisions.

Current launch status is **NO-GO**. The Webull partner-confirmed protocol gate
is unresolved, so provider egress and order mutations remain blocked. The
Supabase production project, production admin hosting, SMTP, backup/recovery,
retention, monitoring, limits, and Free-to-Pro thresholds also require recorded
operator decisions before production launch.

Pull requests are entirely local and secret-free. Hosted development is one
serialized protected-environment deployment from `main`, with exact target and
Git revision handshakes. Supabase branching is not required or assumed.
