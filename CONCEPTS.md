# Concepts

Shared domain vocabulary for this project — entities, named processes, and status concepts with project-specific meaning. Seeded with core domain vocabulary, then accretes as ce-compound and ce-compound-refresh process learnings; direct edits are fine. Glossary only, not a spec or catch-all.

## Ritual Investing

### Daily Ritual
The recurring entry experience that frames investment research through tarot or astrology, then keeps evidence, uncertainty, and limitations adjacent to the interpretation.

### Market-informed
A disclosure that a mystical interpretation has an inspectable market basis, observation context, uncertainty, and reason for each idea rather than supernatural causation or a guarantee.

### Founders' Coven
A first-class company-discovery collection that distinguishes qualification by a woman founder, owner, or chief executive and treats each classification as dated evidence.

### Rowan
The in-app counsel persona who explains readings, market evidence, investment terms, and risk in a warm voice without acting as an adviser or using intimacy to influence a financial decision.

### Grimoire
A curated research collection that groups simulated investment ideas around a legible theme.

### Circle
A themed set of investment ideas that can be explored and, in the simulated product model, copied or edited privately without implying a real adviser or social account.

### Asset Codex
The evidence-rich asset view that connects an idea to its thesis, appearance reason, supporting observations, material risks, simple metrics, and local organization actions.

### Demo state
The explicitly fictional product world containing simulated preferences, profiles, balances, holdings, activity, goals, projections, collections, and entitlement while excluding real credentials and money movement.

### Demo ledger
The append-only authoritative history of simulated contributions, orders, cash movement, and position movement. Current Demo balances and holdings are projections rebuilt from this history; no entry represents real money or brokerage activity.

### Live brokerage account
A regulated, non-Demo investing account whose identity, restrictions, cash, orders, positions, activity, custody, and records are authoritative at the contracted brokerage provider.

### Funding relationship
The single active link between a member-authorized external bank account and a live brokerage account. Bank-link health is distinct from the brokerage provider's authority over deposits, withdrawals, settlement, and holds.

### Provider command
A durable request to perform one external financial effect. It binds an exact reviewed payload to an idempotency key and remains unresolved until a definitive provider response or reconciliation establishes the outcome.

### Reconciliation case
An auditable operational record opened when provider authority and Ritual's local projection do not agree or when a provider command has an ambiguous outcome. It blocks affected mutations until authoritative evidence supports resolution.

### Published projection
An explicit public- or member-safe database view of the currently approved editorial revision. It contains only allowlisted fields and is the sole source eligible for shared public caching.

### Account tenant
The v1 ownership boundary for server data. Each authenticated Ritual Investing account maps to one server-assigned tenant identifier that clients cannot choose, while future multi-user organization membership remains outside the current model.

### Member bootstrap
The authenticated, bodyless account-preparation process that maps a verified member identity to the canonical server-owned session snapshot used to route onboarding or member entry.

### Intention
A yearly financial goal used to organize and explain progress within the simulated investing experience.

### Future Mirror
A projection view that relates simulated contributions and modeled returns to an Intention while presenting outcomes as uncertain scenarios rather than guarantees.

### Onboarding finalization
The authenticated, idempotent member command that atomically attaches reviewed investing and ritual preferences, optional astrology personalization, consent receipts, and completed onboarding state to an account tenant after hosted sign-up or sign-in.
