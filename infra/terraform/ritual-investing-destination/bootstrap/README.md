# Destination bootstrap state recovery

Use the [shared operator CLI](../README.md) for bootstrap. This root creates the
private prod and staging state buckets with `prevent_destroy`. It begins with
durable local state in the designated host's canonical private account directory:

```text
~/.local/state/ritual-investing-destination/accounts/<verified-account-id>/
```

The profile must record that host's exact `socket.gethostname()`. An account-scoped
filesystem lock serializes local callers; it cannot coordinate another host. Keep
the original host and recovery directory throughout incomplete bootstrap. Do not
copy the directory to start a second bootstrap or change the host designation to
bypass recovery.

The CLI preserves the checked-in configuration, provider lock, and revision before
planning. Apply consumes the saved plan before Terraform starts. Its working
state, backups, emergency state, and private logs survive failure. Successful
bucket creation is followed by ownership/privacy checks and a no-change plan.

Migration stages `backend.remote.tf.template` in the private working directory,
leaving the checkout unchanged. Terraform copies bootstrap state into
`ritual-investing-terraform-state-prod` at `bootstrap/terraform.tfstate` using
`init -migrate-state`. The CLI permits noninteractive copying only after verifying
the destination and proving the remote key absent. `-reconfigure` reconnects to an
established authority; it does not copy state. Workload state uses
`workloads/terraform.tfstate` in each environment's separate bucket.

| Preserved evidence | Recovery |
| --- | --- |
| No consumed plan or state, buckets proven absent | A fresh plan may archive an unused snapshot and select a new checked-in revision. |
| Partial local bucket creation | Obtain a fresh plan at the original revision from valid preserved state. If prod exists, R2 credentials must prove the remote bootstrap key absent. |
| Both buckets created, missing R2 object credentials | Retain `AwaitingBackendCredentials`; supply environment credentials and run bootstrap `resume`. |
| Remote key absent, valid local state | Local state remains authoritative; resume may migrate it. |
| Remote state matches preserved local state | Compare lineage, serial, resource addresses/IDs, and complete contents; reconnect without copying and verify read-back. |
| Divergent local/remote state or any `errored.tfstate` | Stop for explicit recovery. Do not overwrite remote state or substitute an older normal state file. |

Resume never replays apply. It validates the original snapshot and Terraform
executable identity and reports the original revision, even after checkout code
changes. The current profile must remain committed and match the account and
host. Incomplete bucket inventory cannot migrate. Phase metadata records progress;
it does not establish state authority.

After matching read-back, the CLI runs **two real Terraform locking probes**, one
per state bucket. Each uses a private resource-free root and disposable
`locking-check/<random-id>/terraform.tfstate` key. A Terraform plan holds the lock
at a controlled input prompt while a second contender must fail with the same
lock identity. The first plan exits normally; a later plan must then acquire and
release the lock. Read-only signed S3 GETs observe `.tflock`; Terraform alone
creates/removes locks. Failed contention, release, or reacquisition stops bootstrap
without force-unlock.

`RemoteReady` records migration and both proofs. Apply/resume must still pass
current resource checks and a refreshed remote no-change plan. Every workload
operation checks bootstrap readiness again against its selected checkout.

Keep `snapshot/`, `work/`, `authoritative-local.tfstate`, normal/backup/emergency
state, phase metadata, referenced plans, and locking evidence until recovery no
longer depends on them. Directories use `0700`; files use `0600`. Inspect sensitive
diagnostics only in protected local storage. Do not delete recovery files to
restart or publish their contents.

Offline tests verify recovery logic, not destination ownership, R2 compatibility,
or hosted locking. Live bootstrap remains pending until those checks run with
administrator-verified destination credentials.
