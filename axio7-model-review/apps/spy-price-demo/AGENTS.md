# SPY price demo instructions

Read `../../PROJECT_CONTRACT.md` and the repository-level `AGENTS.md` before modifying this app.

- Compose the interface graph first: the replay graph is the primary decision surface and surrounding controls support it.
- Use a black-and-white UI. Reserve color exclusively for up/down movement; do not introduce semantic, decorative, or status colors.
- Validate every artifact at its boundary with Ajv before rendering it.
- Do not silently fall back to fixtures. Fixture data is allowed only when the explicitly selected fixture environment is active; artifact failures must be visible and fail closed.
- Keep quantitative math out of TypeScript. Render exported research values and their metadata without recomputing them.
- Keep features in feature-owned folders and run scoped TypeScript and Vitest checks after changes.
- Treat these chart settings as immutable:

```text
animation: false
animationDuration: 0
animationDurationUpdate: 0
```
