"""Shared noninteractive destination CLI; raw Terraform/API bytes stay private."""
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import sys
import uuid

from cloud_read import CloudError, CloudRead
from plan_policy import PolicyError, inspect_plan
from state_backend import (BackendError, BackendSpec, BootstrapManager, S3StateReader,
                           TerraformCommand, _json_bytes, _read_json, account_lock,
                           private_account_directory, private_write, verify_remote_locking)

CLI_VERSION = "1"
TERRAFORM_CONFIG = b"disable_checkpoint = true\n"
FEATURE = Path(__file__).resolve().parent
ACTIONS = {"plan", "apply", "verify", "resume"}
TARGETS = {"bootstrap", "staging", "prod"}
RECOVERY = {
    "invalid-arguments": "Use an explicit action, --profile leoinvestment, and one --target; apply requires --artifact.",
    "action-unavailable": "Apply, verify, and resume require the safe execution unit; this CLI currently supports planning only.",
    "prerequisite-failure": "Provide the committed administrator-verified destination profile, designated host, destination credentials, and Terraform 1.15.x.",
    "unsafe-environment": "Remove inherited Terraform, backend, API, or Git overrides and retry.",
    "stale-inputs": "Commit the intended destination inputs and obtain a fresh plan; preserve unrelated work.",
    "unsafe-plan": "Review the destination-only configuration and obtain a fresh safe plan.",
    "bootstrap-incomplete": "Complete bootstrap recovery and independently verify a refreshed remote no-change bootstrap plan.",
    "recovery-required": "Preserve the canonical account recovery directory and resolve its state authority before planning.",
    "lock-contention": "Retry after the existing account operator releases the lock.",
    "terraform-failure": "Inspect protected local diagnostics, correct the prerequisite, and obtain a fresh plan.",
    "verification-failure": "Verify account permissions and destination inventory before retrying; no automatic adoption is permitted.",
    "planned-changes": "Retain the private artifact directory for explicit apply once safe execution is available.",
    "planned-no-change": "Retain the private artifact; this plan does not establish independent hosted postconditions.",
    "internal-failure": "Preserve private recovery artifacts and inspect the local installation before retrying.",
}


class ProvisionError(Exception):
    def __init__(self, outcome):
        self.outcome = outcome
        super().__init__(RECOVERY[outcome])


def fail(outcome):
    raise ProvisionError(outcome)


@dataclass(frozen=True)
class Options:
    action: str
    profile: str
    target: str
    artifact: str | None
    json: bool


def parse_arguments(arguments):
    # No abbreviations, duplicate flags, alternate account selectors, positional
    # target defaults, or echoed caller strings (which could themselves be secrets).
    if not arguments or arguments[0] not in ACTIONS:
        fail("invalid-arguments")
    values = {}
    index = 1
    while index < len(arguments):
        flag = arguments[index]
        if flag not in ("--profile", "--target", "--artifact", "--json") or flag in values:
            fail("invalid-arguments")
        if flag == "--json":
            values[flag] = True
        else:
            index += 1
            if index == len(arguments) or arguments[index].startswith("--"):
                fail("invalid-arguments")
            values[flag] = arguments[index]
        index += 1
    action, target = arguments[0], values.get("--target")
    if values.get("--profile") != "leoinvestment" or target not in TARGETS:
        fail("invalid-arguments")
    if (action == "apply") != ("--artifact" in values) or (action == "resume" and target != "bootstrap"):
        fail("invalid-arguments")
    return Options(action, "leoinvestment", target, values.get("--artifact"), bool(values.get("--json")))


def check_environment(environment):
    aws_credentials = {"AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_SESSION_TOKEN"}
    for name in environment:
        if (name.startswith(("TF_", "GIT_")) or
                name.startswith("AWS_") and name not in aws_credentials or
                name.startswith("CLOUDFLARE_") and name != "CLOUDFLARE_API_TOKEN" or
                name == "RITUAL_CLOUDFLARE_API_BASE_URL"):
            fail("unsafe-environment")


def read_profile(feature=FEATURE):
    try:
        profile = _read_json(feature / "profiles/leoinvestment.json")
    except BackendError:
        fail("prerequisite-failure")
    if (not isinstance(profile, dict) or set(profile) != {"schema_version", "account_id", "account_name", "settings_verified", "bootstrap_host"} or
            profile.get("schema_version") != 1 or profile.get("account_name") != "LeoInvestment" or
            profile.get("settings_verified") is not True or profile.get("bootstrap_host") != socket.gethostname()):
        fail("prerequisite-failure")
    try:
        BackendSpec(profile.get("account_id"), "bootstrap")
    except BackendError:
        fail("prerequisite-failure")
    return profile


def _git(repository, *arguments):
    process = subprocess.run(["git", "-c", "core.fsmonitor=false", *arguments], cwd=repository,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.DEVNULL)
    if process.returncode != 0:
        fail("stale-inputs")
    return process.stdout


def root_for(feature, target):
    return feature / ("bootstrap" if target == "bootstrap" else "environments/" + target)


def _relevant(path, feature_relative, target):
    try:
        relative = path.relative_to(feature_relative)
    except ValueError:
        return False
    # Every CLI/policy helper is bound, including future feature-owned helpers.
    if "tests" not in relative.parts and path.suffix in (".py", ".sh"):
        return True
    if relative == Path("profiles/leoinvestment.json"):
        return True
    selected = Path("bootstrap" if target == "bootstrap" else "environments/" + target)
    in_root = relative.parent == selected
    in_module = relative.parent == Path("modules/account-resources")
    return (in_root or in_module) and (path.name.endswith((".tf", ".tf.json", ".tfvars", ".tfvars.json")) or
                                       path.name in ("catalog.json", "backend.hcl", ".terraform.lock.hcl", "backend.remote.tf.template"))


def digest_file(path):
    if path.is_symlink() or not path.is_file():
        fail("stale-inputs")
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for data in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(data)
    return digest.hexdigest()


def inspect_inputs(repository, feature, target):
    """Compare HEAD blobs, index, and disk; ignored Terraform inputs also count."""
    repository, feature = Path(repository).resolve(), Path(feature).resolve()
    if Path(os.fsdecode(_git(repository, "rev-parse", "--show-toplevel")).strip()).resolve() != repository:
        fail("stale-inputs")
    feature_relative = feature.relative_to(repository)
    revision = _git(repository, "rev-parse", "HEAD").decode().strip()
    if not re.fullmatch(r"[0-9a-f]{40,64}", revision):
        fail("stale-inputs")
    tracked = {Path(os.fsdecode(name)) for name in _git(repository, "ls-tree", "-rz", "--name-only", "HEAD").split(b"\0") if name}
    selected = {p for p in tracked if _relevant(p, feature_relative, target)}
    actual = set()
    for directory, folders, files in os.walk(feature, followlinks=False):
        # Terraform provider caches and test fixtures aren't active configuration.
        folders[:] = [name for name in folders if name not in (".terraform", "__pycache__", "tests")]
        for name in folders:
            if (Path(directory) / name).is_symlink():
                fail("stale-inputs")
        for name in files:
            path = (Path(directory) / name).relative_to(repository)
            if _relevant(path, feature_relative, target):
                actual.add(path)
    required = {feature_relative / name for name in ("provision.py", "provision.sh", "plan_policy.py", "cloud_read.py", "state_backend.py", "profiles/leoinvestment.json")}
    required.add(root_for(feature_relative, target) / ".terraform.lock.hcl")
    if selected != actual or not required <= selected:
        fail("stale-inputs")
    changed = {Path(os.fsdecode(name)) for name in _git(repository, "diff", "--name-only", "-z", "HEAD", "--", str(feature_relative)).split(b"\0") if name}
    if any(_relevant(path, feature_relative, target) for path in changed):
        fail("stale-inputs")
    # Compare blobs ourselves, so skip-worktree/assume-unchanged cannot hide edits.
    inputs = {}
    for relative in sorted(selected):
        path = repository / relative
        if path.is_symlink() or not path.is_file() or any(parent.is_symlink() for parent in path.parents):
            fail("stale-inputs")
        expected = _git(repository, "show", "HEAD:" + str(relative))
        if path.read_bytes() != expected or _git(repository, "show", ":" + str(relative)) != expected:
            fail("stale-inputs")
        inputs[str(relative)] = hashlib.sha256(expected).hexdigest()
    if target == "bootstrap" and any(Path(p).parent == root_for(feature_relative, target) and
                                      p.endswith((".tf.json", ".tfvars", ".tfvars.json")) for p in inputs):
        # U2 retains only *.tf inputs. Fail rather than hash a file that its workdir
        # would omit. Bootstrap account selection comes through a controlled env var.
        fail("stale-inputs")
    return {"revision": revision, "inputs": inputs}


def stage_inputs(repository, artifact, inventory):
    snapshot = Path(artifact) / "snapshot"
    for relative, digest in inventory["inputs"].items():
        data = (Path(repository) / relative).read_bytes()
        if hashlib.sha256(data).hexdigest() != digest:
            fail("stale-inputs")
        private_write(snapshot / relative, data)
    return snapshot


def terraform_command(account, artifact, environment):
    selected = environment.get("RITUAL_TERRAFORM_BIN", "terraform")
    binary = shutil.which(selected, path=environment.get("PATH"))
    if binary is None:
        fail("prerequisite-failure")
    binary = str(Path(binary).resolve())
    identity = {"path": binary, "sha256": digest_file(Path(binary))}
    env = dict(environment)
    # Explicit empty CLI config prevents a user's ~/.terraformrc from redirecting
    # provider installation or supplying dev overrides. Caller TF_* stays forbidden.
    private_write(Path(artifact) / "terraform.rc", TERRAFORM_CONFIG)
    env.update(TF_CLI_CONFIG_FILE=str(Path(artifact) / "terraform.rc"),
               TF_VAR_cloudflare_account_id=account, AWS_REGION="auto")
    command = TerraformCommand(binary, env)
    if command.run(["version", "-json"], artifact, "version") != 0:
        fail("prerequisite-failure")
    try:
        version = _read_json(command.last_output).get("terraform_version")
    except (BackendError, AttributeError):
        fail("prerequisite-failure")
    if not isinstance(version, str) or not re.fullmatch(r"1\.15\.\d+", version):
        fail("prerequisite-failure")
    identity["version"] = version
    return command, identity


def plan_identity(manifest):
    return hashlib.sha256(_json_bytes({key: manifest[key] for key in (
        "schema_version", "cli_version", "revision", "inputs", "profile", "target", "account", "backend",
        "terraform", "plan_sha256")})).hexdigest()


def validate_artifact(artifact, repository, feature, profile, target, terraform_identity):
    """U4 entry point: recompute current inputs, snapshot, plan, and tool identity.

    This validates integrity, not permission to apply or state authority. Call it
    under the canonical account lock after environment/account checks, then run
    policy and independently refreshed destination postconditions before mutation.
    """
    artifact, repository, feature = Path(artifact), Path(repository).resolve(), Path(feature).resolve()
    canonical = private_account_directory(profile["account_id"])
    if (artifact.is_symlink() or any(parent.is_symlink() for parent in artifact.parents) or
            not artifact.is_absolute() or artifact.resolve().parent != canonical / "plans" or
            not re.fullmatch(r"[0-9a-f]{32}", artifact.name) or canonical.is_relative_to(repository)):
        fail("stale-inputs")
    manifest = _read_json(artifact / "manifest.json")
    current = inspect_inputs(repository, feature, target)
    if (not isinstance(manifest, dict) or manifest.get("schema_version") != 1 or manifest.get("cli_version") != CLI_VERSION or
            manifest.get("profile") != "leoinvestment" or manifest.get("target") != target or
            manifest.get("account") != profile["account_id"] or manifest.get("backend") != BackendSpec(profile["account_id"], target).identity() or
            manifest.get("terraform") != terraform_identity or
            manifest.get("revision") != current["revision"] or manifest.get("inputs") != current["inputs"]):
        fail("stale-inputs")
    if (digest_file(Path(terraform_identity["path"])) != terraform_identity["sha256"] or
            (artifact / "terraform.rc").is_symlink() or
            (artifact / "terraform.rc").read_bytes() != TERRAFORM_CONFIG):
        fail("stale-inputs")
    snapshot = artifact / "snapshot"
    files = set()
    for path in snapshot.rglob("*"):
        if path.is_symlink():
            fail("stale-inputs")
        if path.is_file():
            files.add(str(path.relative_to(snapshot)))
    if files != set(current["inputs"]):
        fail("stale-inputs")
    for relative, digest in current["inputs"].items():
        if digest_file(snapshot / relative) != digest:
            fail("stale-inputs")
    if (manifest.get("plan_sha256") != digest_file(artifact / "plan.tfplan") or
            manifest.get("plan_identity") != plan_identity(manifest)):
        fail("stale-inputs")
    return manifest


def require_bootstrap_gate(manager):
    # A phase marker is not fresh hosted evidence. U4 will implement a refreshed
    # remote no-change gate here before staging workload backend configuration.
    fail("bootstrap-incomplete")


def prepare_plan(options, receipt, feature=FEATURE):
    repository = feature.parents[2]
    check_environment(os.environ)
    profile = read_profile(feature)
    inventory = inspect_inputs(repository, feature, options.target)
    receipt.update(account=profile["account_id"], revision=inventory["revision"])
    if not os.environ.get("CLOUDFLARE_API_TOKEN"):
        fail("prerequisite-failure")
    directory = private_account_directory(profile["account_id"])
    if directory.is_relative_to(repository.resolve()):
        fail("prerequisite-failure")
    artifact = directory / "plans" / uuid.uuid4().hex
    # Creation through private_write sets every ancestor and file private.
    private_write(artifact / "terraform.rc", TERRAFORM_CONFIG)
    receipt["artifact"] = str(artifact)
    with account_lock(directory):
        cloud = CloudRead(profile["account_id"], artifact)
        cloud.verify_account()
        terraform, identity = terraform_command(profile["account_id"], artifact, os.environ)
        spec = BackendSpec(profile["account_id"], options.target)
        bootstrap = BootstrapManager(BackendSpec(profile["account_id"], "bootstrap"), directory, terraform,
                                     S3StateReader(), cloud.verify_buckets,
                                     lambda backend, storage: verify_remote_locking(backend, storage, terraform, S3StateReader()),
                                     designated_host=profile["bootstrap_host"])
        if options.target != "bootstrap":
            require_bootstrap_gate(bootstrap)
        cloud.require_bootstrap_absent()
        snapshot = stage_inputs(repository, artifact, inventory)
        selected_root = snapshot / root_for(feature.relative_to(repository), options.target)
        phase = bootstrap.prepare(selected_root, inventory["revision"])
        if phase.get("revision") != inventory["revision"] or phase.get("stage") != "LocalPrepared" or phase.get("plan_consumed"):
            fail("recovery-required")
        # Existing unconsumed recovery snapshots must equal this exact revision.
        for source in bootstrap.snapshot.iterdir():
            if source.read_bytes() != (selected_root / source.name).read_bytes():
                fail("stale-inputs")
        bootstrap.initialize_local()
        saved_plan = artifact / "plan.tfplan"
        code = terraform.run(["plan", "-input=false", "-no-color", "-lock-timeout=0s", "-detailed-exitcode",
                              "-out=" + str(saved_plan)], bootstrap.workdir, "plan")
        if code not in (0, 2):
            fail("terraform-failure")
        if terraform.run(["show", "-json", str(saved_plan)], bootstrap.workdir, "show") != 0:
            fail("terraform-failure")
        plan = _read_json(terraform.last_output)
        private_write(artifact / "plan.private.json", _json_bytes(plan))
        catalog = None if options.target == "bootstrap" else _read_json(selected_root / "catalog.json")
        counts = inspect_plan(plan, profile["account_id"], options.target, catalog)
        if (code == 2) != (counts["create"] + counts["update"] + counts["delete"] > 0):
            fail("unsafe-plan")
        # Refuse input/binary races before returning a useful saved-plan receipt.
        if inspect_inputs(repository, feature, options.target) != inventory or digest_file(Path(identity["path"])) != identity["sha256"]:
            fail("stale-inputs")
        manifest = {"schema_version": 1, "cli_version": CLI_VERSION, **inventory,
                    "profile": options.profile, "target": options.target, "account": profile["account_id"],
                    "backend": spec.identity(), "terraform": identity, "plan_sha256": digest_file(saved_plan)}
        manifest["plan_identity"] = plan_identity(manifest)
        private_write(artifact / "manifest.json", _json_bytes(manifest))
        validate_artifact(artifact, repository, feature, profile, options.target, identity)
        receipt.update(plan_identity=manifest["plan_identity"], counts=counts)
        return "planned-changes" if code == 2 else "planned-no-change"


def main(arguments=None):
    os.umask(0o077)
    arguments = sys.argv[1:] if arguments is None else arguments
    json_mode = "--json" in arguments
    receipt = {"schema_version": 1, "action": None, "profile": None, "target": None,
               "account": None, "revision": None, "plan_identity": None,
               "counts": None, "artifact": None, "outcome": None, "recovery": None}
    try:
        options = parse_arguments(arguments)
        receipt.update(action=options.action, profile=options.profile, target=options.target)
        if options.action != "plan":
            fail("action-unavailable")
        outcome = prepare_plan(options, receipt)
    except ProvisionError as error:
        outcome = error.outcome
    except PolicyError:
        outcome = "unsafe-plan"
    except CloudError:
        outcome = "verification-failure"
    except BackendError as error:
        # Backend diagnostics are constants, but emit only the shared vocabulary.
        outcome = "lock-contention" if str(error) == "Another operator holds the account lock; retry after release." else "recovery-required"
    except (Exception, KeyboardInterrupt):
        # Provider/API/parser exceptions may contain sensitive payloads. No traceback.
        outcome = "internal-failure"
    receipt.update(outcome=outcome, recovery=RECOVERY[outcome])
    if receipt["artifact"]:
        try:
            private_write(Path(receipt["artifact"]) / "receipt.json", _json_bytes(receipt))
        except Exception:
            receipt.update(outcome="internal-failure", recovery=RECOVERY["internal-failure"])
    if json_mode:
        print(json.dumps(receipt, sort_keys=True, separators=(",", ":")))
    else:
        print(f"{receipt['action'] or 'request'} {receipt['target'] or 'destination'}: {receipt['outcome']}")
        for key in ("account", "revision", "plan_identity", "counts", "artifact"):
            if receipt[key] is not None:
                print(f"{key}: {json.dumps(receipt[key], sort_keys=True)}")
        print(receipt["recovery"])
    return 0 if receipt["outcome"] in ("planned-changes", "planned-no-change") else 1


if __name__ == "__main__":
    raise SystemExit(main())
