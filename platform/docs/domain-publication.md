# Production domain publication

The current domain cutover design, ownership, workflow, verification and recovery
instructions are maintained in the repository-level
[domain publication runbook](../../docs/domain-publication.md).

The application and domain belong to distinct Cloudflare accounts. Use the
reviewed GitHub Actions gateway workflow described there. The earlier local OAuth
preflight could not see the domain account and did not change DNS or deploy it.
