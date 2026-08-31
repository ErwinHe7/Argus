# Ritual Investing static surfaces

This package assembles and verifies the landing, Demo, and member static
artifacts. It does not own authentication, application data, quantitative
research, infrastructure state, or backend compute.

The environment names are `dev`, `staging`, and `prod`:

- `dev` builds and runs locally on loopback only.
- `staging` is automatically attempted from the immutable artifact produced by
  a canonical push to `main`.
- `prod` is a manual promotion of that exact retained artifact after manual
  evidence; it is never rebuilt during promotion.

Run the fast local checks with:

```sh
npm ci
npm run typecheck
npm test
npm run pages:config:check
```

The automatic workflow intentionally excludes browser, integration, device,
simulator, hosted acceptance, and restore work. Those checks are manual release
evidence and are not required status checks. See the
[release runbook](../docs/ritual-investing/production-release-runbook.md) for
promotion and recovery.

`public beta` is a product-lifecycle label. It does not introduce a `beta`
deployment environment. The provider's legacy physical Supabase label `beta`
for project ref `zbgjjufjkhfhirbuuolv` maps only to staging.
