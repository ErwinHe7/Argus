# Deployment capability audit — 2026-09-08

This is a capability receipt, not a deployment or account-purchase receipt.

| Check | Observed result |
|---|---|
| Existing target host | No VPS hostname was supplied; no user `.ssh` directory/config or machine-wide `ssh_config` was present |
| Available transport | Windows OpenSSH `ssh.exe` and `scp.exe` present |
| Provider tooling | No `terraform`, `doctl`, `hcloud`, `aws` or `gcloud` executable found on PATH |
| Cloudflare identity | Read-only `wrangler whoami` exit 0, authenticated output and Workers write scope present; identifying details and secrets withheld |
| Website runtime | Worker `leo`, retained Next.js backend wrapper and static overlay, existing `PUBLIC_MARKET_MAP` service binding |
| Native compute target | No configured VPS; Ubuntu 24.04 WSL is available for local syntax/unit validation, not a purchased remote server |
| Prior infrastructure | Rust crate includes a Railway/Docker recipe for `quantd`/`quantctl`; it does not package this new shortlist/research service and was not deployed |
| Actions performed | Read-only audit, local source-package implementation and tests |
| Actions not performed | No resource purchase/provision, SSH connection, remote install, public-port exposure, website deploy, broker authentication or trade |

The existing Cloudflare Worker serves the website. It cannot launch the native
Rust binary and Python daemon unchanged: `node:child_process` is documented as a
non-functional stub. A separate VPS, or separately designed container runtime,
must run these native processes. [Official Workers compatibility](https://developers.cloudflare.com/workers/runtime-apis/nodejs/#non-functional-stub-modules)

For the proposed VPS, the concrete missing inputs are an actual provisioned
Ubuntu x64 host, authorized SSH login, valid current data on that host, and a
configured HTTPS route for publishing the allowlisted result snapshot. Creating
the machine also requires the owner's provider account and payment. No password,
private SSH key or provider API key should be pasted into chat.

Website publication should carry only a bounded, dated candidate list and public
publisher status. Historical bars, broker account information, local state and
private controls stay off the public result endpoint. A working heartbeat alone
must never make an old market snapshot appear fresh.
