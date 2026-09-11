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

from cloud_read import CloudError, CloudRead, OutsideScope
from plan_policy import (PolicyError, inspect_plan, inspect_outputs, expected_resources, owned_resources)
from state_backend import (BackendError, BackendSpec, BootstrapManager, S3StateReader,
                           TerraformCommand, _json_bytes, _read_json, account_lock,
                           private_account_directory, private_write, verify_remote_locking, read_state, _write_backend)

CLI_VERSION = "1"
TERRAFORM_CONFIG = b"disable_checkpoint = true\n"
FEATURE = Path(__file__).resolve().parent
ACTIONS = {"plan", "apply", "verify", "resume"}
TARGETS = {"bootstrap", "staging", "prod"}
RECOVERY = {
    "invalid-arguments": "Use an explicit action, --profile leoinvestment, and one --target; apply requires --artifact.",
    "prerequisite-failure": "Provide the committed administrator-verified destination profile, designated host, destination credentials, and Terraform 1.15.x.",
    "unsafe-environment": "Remove inherited Terraform, backend, API, or Git overrides and retry.",
    "stale-inputs": "Commit the intended destination inputs and obtain a fresh plan; preserve unrelated work.",
    "unsafe-plan": "Review the destination-only configuration and obtain a fresh safe plan.",
    "bootstrap-incomplete": "Complete bootstrap recovery and independently verify a refreshed remote no-change bootstrap plan.",
    "recovery-required": "Preserve the canonical account recovery directory and resolve its state authority before planning.",
    "lock-contention": "Retry after the existing account operator releases the lock.",
    "terraform-failure": "Inspect protected local diagnostics, correct the prerequisite, and obtain a fresh plan.",
    "verification-failure": "Verify account permissions and destination inventory before retrying; no automatic adoption is permitted.",
    "planned-changes": "Apply this exact private artifact explicitly while its checked-in inputs and state remain current.",
    "applied": "Provisioning and refreshed no-change verification succeeded; retain private recovery evidence.",
    "verified": "Owned destination resources and refreshed no-change state are verified.",
    "resumed": "Original bootstrap snapshot migrated and verified; fresh current-checkout reconciliation is required before workloads.",
    "consumed-plan": "This saved plan was already consumed; resume bootstrap recovery or obtain a fresh plan from retained state.",
    "partial-apply": "Terraform apply failed; retain normal, backup, emergency state and private logs before recovery or a fresh plan.",
    "outside-provisioning-scope": "Destination activation is outside provisioning scope; no automatic cleanup is authorized.",
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
        if (name.startswith("TF_") or name.startswith("GIT_") and name != "GIT_PAGER" or
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
    process = subprocess.run(["git", "--no-pager", "-c", "core.fsmonitor=false", *arguments], cwd=repository,
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
    in_root = relative.parent == selected or target != "bootstrap" and relative.parent == Path("bootstrap")
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


def validate_backend_sources(root, target):
    """The selected roots have a fixed backend contract, not an extensible backend DSL."""
    def normalized(path):
        if path.is_symlink() or not path.is_file():
            fail("stale-inputs")
        return re.sub(r"\s+", "", re.sub(r"#[^\n]*", "", path.read_text()))
    bucket = "ritual-investing-terraform-state-" + ("prod" if target == "bootstrap" else target)
    key = "bootstrap/terraform.tfstate" if target == "bootstrap" else "workloads/terraform.tfstate"
    if target == "bootstrap":
        expected = 'terraform{backend"local"{}}'
        if normalized(root / "backend.remote.tf.template") != 'terraform{backend"s3"{}}':
            fail("stale-inputs")
    else:
        expected = 'terraform{backend"s3"{bucket="' + bucket + '"key="' + key + '"region="auto"skip_region_validation=true}}'
    if normalized(root / "backend.tf") != expected:
        fail("stale-inputs")
    fields = {"bucket": bucket, "key": key, "region": "auto", "encrypt": True, "use_lockfile": True,
              "use_path_style": True, "skip_credentials_validation": True, "skip_region_validation": True,
              "skip_requesting_account_id": True, "skip_metadata_api_check": True, "skip_s3_checksum": True}
    if normalized(root / "backend.hcl") != "".join(name + "=" + json.dumps(value) for name, value in fields.items()):
        fail("stale-inputs")


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
    if any(Path(p).parent == root_for(feature_relative, "bootstrap") and
                                      p.endswith((".tf.json", ".tfvars", ".tfvars.json")) for p in inputs):
        # U2 retains only *.tf inputs. Fail rather than hash a file that its workdir
        # would omit. Bootstrap account selection comes through a controlled env var.
        fail("stale-inputs")
    for selected_target in (("bootstrap",) if target == "bootstrap" else ("bootstrap", target)):
        validate_backend_sources(root_for(feature, selected_target), selected_target)
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
    config_path = Path(artifact) / "terraform.rc"
    if config_path.exists():
        if config_path.is_symlink() or config_path.read_bytes() != TERRAFORM_CONFIG:
            fail("stale-inputs")
    else:
        private_write(config_path, TERRAFORM_CONFIG)
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
        "terraform", "plan_sha256", "state_sha256", "execution_mode")})).hexdigest()


def validate_artifact(artifact, repository, feature, profile, target, terraform_identity):
    """Recompute current inputs, snapshot, plan, and tool identity.

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


def artifact_path(value, directory, repository):
    artifact = Path(value)
    if (not artifact.is_absolute() or artifact.is_symlink() or any(parent.is_symlink() for parent in artifact.parents) or
            artifact.resolve().parent != directory / "plans" or not re.fullmatch(r"[0-9a-f]{32}", artifact.name) or
            directory.is_relative_to(repository.resolve())):
        fail("stale-inputs")
    return artifact


def work_snapshot(artifact, inventory):
    """Keep the verified input snapshot immutable; Terraform works on a private copy."""
    work = artifact / "work"
    for relative, digest in inventory["inputs"].items():
        data = (artifact / "snapshot" / relative).read_bytes()
        if hashlib.sha256(data).hexdigest() != digest:
            fail("stale-inputs")
        private_write(work / relative, data)
    return work


def check_work(work, snapshot, inventory, *, remote_bootstrap=False):
    expected = set(inventory["inputs"])
    for relative in expected:
        path = work / relative
        if remote_bootstrap and relative.endswith("/bootstrap/backend.tf"):
            data = (snapshot / Path(relative).parent / "backend.remote.tf.template").read_bytes()
        else:
            data = (snapshot / relative).read_bytes()
        if path.is_symlink() or not path.is_file() or path.read_bytes() != data:
            fail("stale-inputs")
    for path in work.rglob("*"):
        if path.is_symlink():
            # Terraform's provider installation may contain symlinks, but no input
            # path or parent outside its cache may use one.
            if ".terraform" not in path.parts:
                fail("stale-inputs")
        if path.name == "backend.tfbackend.json" and ".terraform" not in path.parts:
            target = path.parent.name
            if target not in TARGETS:
                fail("stale-inputs")
            account = _read_json(snapshot / next(relative for relative in inventory["inputs"] if relative.endswith("/profiles/leoinvestment.json")))["account_id"]
            if _read_json(path) != BackendSpec(account, target).configuration():
                fail("stale-inputs")
        if ".terraform" not in path.parts and path.is_file() and path.name.endswith((".tf", ".tf.json", ".tfvars", ".tfvars.json")):
            if str(path.relative_to(work)) not in expected:
                fail("stale-inputs")


def remote_init(terraform, root, spec, *, bootstrap=False):
    if bootstrap:
        private_write(root / "backend.tf", (root / "backend.remote.tf.template").read_bytes())
    _write_backend(root / "backend.tfbackend.json", spec)
    code = terraform.run(["init", "-input=false", "-no-color", "-lockfile=readonly", "-reconfigure",
                          "-backend-config=backend.tfbackend.json"], root, "remote-init")
    terraform_ok(terraform, code)


def terraform_ok(terraform, code, outcome="terraform-failure"):
    if code != 0:
        if terraform.last_output and b"Error acquiring the state lock" in terraform.last_output.read_bytes():
            fail("lock-contention")
        fail(outcome)


def state_value(spec, root, reader, artifact, mode):
    if any(artifact.parent.parent.rglob("errored.tfstate")):
        fail("recovery-required")
    if mode == "local":
        return read_state(root / "terraform.tfstate") if (root / "terraform.tfstate").exists() else None
    if not reader.available:
        fail("prerequisite-failure")
    path = artifact / ("state-" + spec.target + "-" + uuid.uuid4().hex + ".private.json")
    return read_state(path) if reader.get(spec, path) else None


def state_digest(state):
    return hashlib.sha256(_json_bytes(state)).hexdigest()


def initialized(directory, spec, state):
    path = directory / ("initialized-" + spec.target + ".json")
    if not path.exists():
        return False
    record = _read_json(path)
    if (not isinstance(record, dict) or record.get("backend") != spec.identity() or state is None or
            record.get("lineage") != state["lineage"] or record.get("verified") is not True):
        fail("recovery-required")
    return True


def record_initialized(directory, spec, state, revision):
    private_write(directory / ("initialized-" + spec.target + ".json"), _json_bytes({
        "backend": spec.identity(), "lineage": state["lineage"], "verified": True, "revision": revision}))


def show_plan(terraform, root, path, account, target, catalog, update_allowed):
    terraform_ok(terraform, terraform.run(["show", "-json", str(path)], root, "show"))
    plan = _read_json(terraform.last_output)
    counts = inspect_plan(plan, account, target, catalog, initialized=update_allowed)
    return plan, counts


def run_plan(terraform, root, path, account, target, catalog, update_allowed, *, no_change=False):
    code = terraform.run(["plan", "-input=false", "-no-color", "-lock-timeout=0s", "-detailed-exitcode",
                          "-out=" + str(path)], root, "verify-plan" if no_change else "plan")
    if code not in (0, 2):
        terraform_ok(terraform, code, "verification-failure" if no_change else "terraform-failure")
    if no_change and code != 0:
        fail("verification-failure")
    try:
        plan, counts = show_plan(terraform, root, path, account, target, catalog, update_allowed)
    except PolicyError:
        if no_change:
            fail("verification-failure")
        raise
    changes = counts["create"] + counts["update"] > 0 or inspect_outputs(plan, target, expected_resources(target, catalog))
    if (code == 2) != changes:
        fail("verification-failure" if no_change else "unsafe-plan")
    return code, plan, counts


def check_plan_ownership(plan, owned):
    for resource in plan["resource_changes"]:
        before = resource["change"].get("before")
        if before is not None:
            if resource["address"] not in owned or before.get("id") != owned[resource["address"]].get("id"):
                fail("unsafe-plan")


def require_bootstrap_gate(manager, cloud, terraform, reader, artifact, work_feature):
    if not manager.phase_path.exists():
        fail("bootstrap-incomplete")
    manager._guard()
    phase = manager.status()
    evidence = [manager.spec.identity(), BackendSpec(manager.spec.account, "staging").identity()]
    if phase.get("stage") != "RemoteReady" or phase.get("locking_verified") != evidence:
        fail("bootstrap-incomplete")
    cloud.verify_buckets(manager.spec)
    root = work_feature / "bootstrap"
    state = state_value(manager.spec, root, reader, artifact, "remote")
    owned = owned_resources(state, expected_resources("bootstrap", None), manager.spec.account)
    if set(owned) != set(expected_resources("bootstrap", None)) or not initialized(manager.directory, manager.spec, state):
        fail("bootstrap-incomplete")
    remote_init(terraform, root, manager.spec, bootstrap=True)
    run_plan(terraform, root, artifact / "bootstrap-gate.tfplan", manager.spec.account, "bootstrap", None, False, no_change=True)
    return True


def verify_target(terraform, cloud, reader, artifact, root, spec, catalog, directory, mode, revision):
    state = state_value(spec, root, reader, artifact, mode)
    expected = expected_resources(spec.target, catalog)
    owned = owned_resources(state, expected, spec.account)
    if set(owned) != set(expected):
        fail("verification-failure")
    cloud.verify_account()
    cloud.verify_resources(expected, owned, require_all=True)
    _, plan, counts = run_plan(terraform, root, artifact / ("verified-" + uuid.uuid4().hex + ".tfplan"),
                               spec.account, spec.target, catalog, initialized(directory, spec, state), no_change=True)
    check_plan_ownership(plan, owned)
    # Re-read the backend after refresh to detect concurrent replacement/deletion.
    if state_digest(state_value(spec, root, reader, artifact, mode)) != state_digest(state):
        fail("verification-failure")
    record_initialized(directory, spec, state, revision)
    return counts


def prepare_plan(options, receipt, feature=FEATURE):
    return execute(options, receipt, feature)


def execute(options, receipt, feature=FEATURE):
    repository, relative = feature.parents[2], feature.relative_to(feature.parents[2])
    check_environment(os.environ)
    profile = read_profile(feature)
    # Resume intentionally retains its original Terraform snapshot/revision. Only
    # its current account/profile must still be committed and match the host.
    if options.action == "resume":
        profile_path = relative / "profiles/leoinvestment.json"
        if _git(repository, "show", "HEAD:" + str(profile_path)) != (repository / profile_path).read_bytes():
            fail("stale-inputs")
        inventory = None
    else:
        inventory = inspect_inputs(repository, feature, options.target)
        receipt["revision"] = inventory["revision"]
    receipt["account"] = profile["account_id"]
    if not os.environ.get("CLOUDFLARE_API_TOKEN"):
        fail("prerequisite-failure")
    directory = private_account_directory(profile["account_id"])
    if directory.is_relative_to(repository.resolve()):
        fail("prerequisite-failure")
    if options.action == "apply":
        artifact = artifact_path(options.artifact, directory, repository)
        if not (artifact / "manifest.json").is_file():
            fail("stale-inputs")
    else:
        artifact = directory / "plans" / uuid.uuid4().hex
        private_write(artifact / "terraform.rc", TERRAFORM_CONFIG)
    receipt["artifact"] = str(artifact)
    with account_lock(directory):
        cloud = CloudRead(profile["account_id"], artifact)
        cloud.verify_account()
        terraform, identity = terraform_command(profile["account_id"], artifact, os.environ)
        spec, reader = BackendSpec(profile["account_id"], options.target), S3StateReader()
        bootstrap = BootstrapManager(BackendSpec(spec.account, "bootstrap"), directory, terraform, reader, cloud.verify_buckets,
                                     lambda backend, storage: verify_remote_locking(backend, storage, terraform, reader),
                                     designated_host=profile["bootstrap_host"])
        if options.action == "resume":
            phase = bootstrap._preserved()
            receipt["revision"] = phase.get("revision")
            execution = phase.get("execution")
            if not isinstance(execution, dict) or execution.get("terraform") != identity:
                fail("recovery-required")
            # Preserve the original checked-in snapshot; resume never plans an apply.
            original = artifact_path(execution.get("artifact", ""), directory, repository)
            manifest = _read_json(original / "manifest.json")
            if manifest.get("plan_identity") != plan_identity(manifest) or manifest.get("revision") != phase["revision"]:
                fail("stale-inputs")
            for path, digest in manifest["inputs"].items():
                if digest_file(original / "snapshot" / path) != digest:
                    fail("stale-inputs")
            state = state_value(spec, bootstrap.workdir, reader, artifact, "local")
            if state is None:
                state = read_state(directory / "authoritative-local.tfstate")
            cloud.verify_resources(expected_resources("bootstrap", None), owned_resources(state, expected_resources("bootstrap", None), spec.account), require_all=True)
            phase = bootstrap.resume()
            if phase["stage"] != "RemoteReady":
                fail("bootstrap-incomplete")
            receipt["counts"] = verify_target(terraform, cloud, reader, artifact, bootstrap.workdir, spec, None, directory, "remote", phase["revision"])
            return "resumed"

        if options.action == "apply":
            manifest = validate_artifact(artifact, repository, feature, profile, options.target, identity)
            receipt["plan_identity"] = manifest["plan_identity"]
            if (artifact / "consumed.json").exists():
                fail("consumed-plan")
            snapshot = artifact / "snapshot"
            work = artifact / "work"
            check_work(work, snapshot, inventory, remote_bootstrap=manifest["execution_mode"] == "remote")
        else:
            snapshot = stage_inputs(repository, artifact, inventory)
            work = work_snapshot(artifact, inventory)
        work_feature = work / relative
        root, mode = root_for(work_feature, options.target), "remote"
        catalog = None if options.target == "bootstrap" else _read_json(root / "catalog.json")
        expected = expected_resources(options.target, catalog)
        if options.target != "bootstrap":
            require_bootstrap_gate(bootstrap, cloud, terraform, reader, artifact, work_feature)
        elif not bootstrap.phase_path.exists() or bootstrap.status().get("stage") != "RemoteReady":
            mode, root = "local", bootstrap.workdir
            if options.action == "verify":
                fail("bootstrap-incomplete")
            if options.action == "plan":
                if not bootstrap.phase_path.exists():
                    cloud.require_bootstrap_absent()
                phase = bootstrap.prepare(snapshot / root_for(relative, options.target), inventory["revision"])
                if phase.get("revision") != inventory["revision"]:
                    if phase.get("plan_consumed") or phase.get("consumed_plans"):
                        fail("recovery-required")
                    cloud.require_bootstrap_absent()
                    phase = bootstrap.replace_unstarted(snapshot / root_for(relative, options.target), inventory["revision"])
                if phase.get("plan_consumed"):
                    phase = bootstrap.prepare_replan(inventory["revision"])
                for source in bootstrap.snapshot.iterdir():
                    if source.read_bytes() != (snapshot / root_for(relative, options.target) / source.name).read_bytes():
                        fail("stale-inputs")
                bootstrap.initialize_local()
            else:
                phase = bootstrap._preserved()
                if phase.get("revision") != inventory["revision"] or phase.get("plan_consumed"):
                    fail("recovery-required")
        if mode == "remote":
            if options.target == "bootstrap":
                phase = bootstrap.status()
                if phase.get("locking_verified") != [spec.identity(), BackendSpec(spec.account, "staging").identity()]:
                    fail("bootstrap-incomplete")
            remote_init(terraform, root, spec, bootstrap=options.target == "bootstrap")
        if mode == "local" and (root / "backend.tf").read_bytes() != (bootstrap.snapshot / "backend.tf").read_bytes():
            fail("recovery-required")
        state = state_value(spec, root, reader, artifact, mode)
        owned = owned_resources(state, expected, spec.account)
        update_allowed = initialized(directory, spec, state)
        if mode == "local" and (directory / "authoritative-local.tfstate").exists():
            if state_digest(state) != state_digest(read_state(directory / "authoritative-local.tfstate")):
                fail("recovery-required")
        if options.action == "verify":
            if options.target == "bootstrap":
                phase = bootstrap.status()
                if phase.get("locking_verified") != [spec.identity(), BackendSpec(spec.account, "staging").identity()]:
                    fail("bootstrap-incomplete")
                cloud.verify_buckets(spec)
            receipt["counts"] = verify_target(terraform, cloud, reader, artifact, root, spec, catalog, directory, mode, inventory["revision"])
            return "verified"
        if options.action == "plan":
            # Complete inventories catch unmanaged name collisions before Terraform planning.
            cloud.verify_resources(expected, owned, creating=set(expected))
            code, plan, counts = run_plan(terraform, root, artifact / "plan.tfplan", spec.account, spec.target, catalog, update_allowed)
            check_plan_ownership(plan, owned)
            creates = {resource["address"] for resource in plan["resource_changes"] if resource["change"]["actions"] == ["create"]}
            cloud.verify_resources(expected, owned, creating=creates)
            private_write(artifact / "plan.private.json", _json_bytes(plan))
            if inspect_inputs(repository, feature, options.target) != inventory or digest_file(Path(identity["path"])) != identity["sha256"]:
                fail("stale-inputs")
            manifest = {"schema_version": 1, "cli_version": CLI_VERSION, **inventory,
                        "profile": options.profile, "target": options.target, "account": spec.account,
                        "backend": spec.identity(), "terraform": identity, "plan_sha256": digest_file(artifact / "plan.tfplan"),
                        "state_sha256": state_digest(state), "execution_mode": mode}
            manifest["plan_identity"] = plan_identity(manifest)
            private_write(artifact / "manifest.json", _json_bytes(manifest))
            validate_artifact(artifact, repository, feature, profile, options.target, identity)
            receipt.update(plan_identity=manifest["plan_identity"], counts=counts)
            return "planned-changes" if code == 2 else "planned-no-change"

        if manifest["execution_mode"] != mode or manifest["state_sha256"] != state_digest(state):
            fail("stale-inputs")
        check_work(work, snapshot, inventory, remote_bootstrap=mode == "remote")
        plan, counts = show_plan(terraform, root, artifact / "plan.tfplan", spec.account, spec.target, catalog, update_allowed)
        check_plan_ownership(plan, owned)
        creates = {resource["address"] for resource in plan["resource_changes"] if resource["change"]["actions"] == ["create"]}
        cloud.verify_account()
        cloud.verify_resources(expected, owned, creating=creates)
        validate_artifact(artifact, repository, feature, profile, options.target, identity)
        if state_digest(state_value(spec, root, reader, artifact, mode)) != manifest["state_sha256"]:
            fail("stale-inputs")
        # No code path below may replay this binary, even after interruption.
        private_write(artifact / "consumed.json", _json_bytes({"plan_identity": manifest["plan_identity"], "plan_sha256": manifest["plan_sha256"]}))
        if mode == "local":
            bootstrap.consume_plan(manifest["plan_sha256"])
            phase = bootstrap.status()
            phase["execution"] = {"terraform": identity, "artifact": str(artifact)}
            bootstrap._save(phase)
        receipt["counts"] = counts
        code = terraform.run(["apply", "-input=false", "-no-color", "-lock-timeout=0s", str(artifact / "plan.tfplan")], root, "apply")
        if mode == "local":
            try:
                bootstrap.record_apply_result(code)
            except BackendError:
                if code != 0 and not any(directory.rglob("errored.tfstate")):
                    terraform_ok(terraform, code, "partial-apply")
                raise
        terraform_ok(terraform, code, "partial-apply")
        if mode == "local":
            # Verify every initial resource before allowing state migration.
            verify_target(terraform, cloud, reader, artifact, root, spec, catalog, directory, mode, inventory["revision"])
            phase = bootstrap.resume()
            if phase["stage"] != "RemoteReady":
                fail("bootstrap-incomplete")
            mode = "remote"
        verify_target(terraform, cloud, reader, artifact, root, spec, catalog, directory, mode, inventory["revision"])
        return "applied"


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
        outcome = execute(options, receipt)
    except ProvisionError as error:
        outcome = error.outcome
    except PolicyError:
        outcome = "unsafe-plan"
    except OutsideScope:
        outcome = "outside-provisioning-scope"
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
    return 0 if receipt["outcome"] in ("planned-changes", "planned-no-change", "applied", "verified", "resumed") else 1


if __name__ == "__main__":
    raise SystemExit(main())
