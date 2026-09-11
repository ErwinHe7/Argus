# Destination state bootstrap

This root creates the two destination state buckets with `prevent_destroy`.
It begins with the local backend. The repository CLI stages the checked-in
`backend.remote.tf.template` in its private working directory when migrating
bootstrap state to the prod bucket at `bootstrap/terraform.tfstate`.

Before initial bootstrap, the administrator must set `bootstrap_host` in the
destination profile to the designated operator host's exact `socket.gethostname()`
value. The default `null` refuses bootstrap. Its canonical recovery directory is
`~/.local/state/ritual-investing-destination/accounts/<verified-account-id>/` on
that host. Do not copy this directory to start another bootstrap or change the
host during an incomplete migration. The host designation supplies the boundary
that a same-host filesystem lock cannot enforce across machines.

The CLI holds `account_lock(directory)` before every bootstrap operation and
uses `BootstrapManager` in `../state_backend.py` as follows:

1. `prepare(bootstrap_root, revision)` preserves that root's configuration and
   provider lock, then `initialize_local()` initializes the durable working root.
2. The CLI plans and validates its saved plan against the preserved working root.
   It passes the verified account as a controlled `TF_VAR_cloudflare_account_id`
   environment value, rejecting caller-supplied `TF_VAR_*` values. It must not
   add an untracked generated `.auto.tfvars.json` to the preserved root.
3. `consume_plan(plan_sha256)` is persisted **before** the CLI invokes apply.
   `record_apply_result(returncode)` preserves normal state after that attempt.
4. `resume()` uses only the original snapshot and state. It never invokes apply.
   Missing object credentials persist `AwaitingBackendCredentials`. Matching
   remote state reconnects without copying. Divergent state and emergency
   `errored.tfstate` stop recovery. The bootstrap snapshot's revision remains the
   reported revision throughout this process.

The manager's injected `verify_buckets(spec)` callback must establish exact
destination ownership and privacy through authenticated read-only account APIs.
Its `verify_locking(spec, directory)` callback must call the real
`verify_remote_locking(spec, directory, terraform, reader)` helper for the
required state buckets. Callbacks return literal `True` only after verification.
`S3StateReader` signs read-only object GET requests using runtime
`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and optional `AWS_SESSION_TOKEN`.
Only explicit `NoSuchKey` is absence; access failures are never absence.

The real locking probe uses a private, resource-free Terraform root and a unique
`locking-check/<random-id>/terraform.tfstate` backend key. A Terraform plan waits
at a controlled required-variable prompt after acquiring its backend lock. A
signed GET observes `.tflock`; another plan must fail and identify that same lock.
Supplying the fixed probe input releases the first plan normally, after which a
new plan must acquire and release the lock successfully. Terraform alone writes
state and lock objects. No direct object writes or force-unlock are used. The
probe is backed by an actual Terraform 1.15 local contention/release test;
[Terraform's local operation code](https://github.com/hashicorp/terraform/blob/v1.15.0/internal/backend/local/backend_local.go)
places variable input after lock acquisition. The console command does not
acquire this lock in Terraform 1.15 and is not used.

`RemoteReady` records successful migration and the injected locking check.
The CLI must additionally require a remote no-change plan and current
postcondition checks before provisioning workloads. A partial bucket create
retains its state and consumed plan; a fresh plan recovery lifecycle belongs to
the CLI's apply policy. Incomplete inventory cannot migrate automatically.

Keep `work/`, `snapshot/`, normal state, backups, emergency state, phase metadata,
and probe evidence until recovery or verification is complete. There is no exit
cleanup that deletes recoverable state. Directory permissions are `0700`; raw
state, backend metadata and Terraform/S3 responses remain in `0600` files.

Offline tests do not establish destination ownership, R2 compatibility, or hosted
locking success. Those require the plan's U6 execution with verified credentials.
