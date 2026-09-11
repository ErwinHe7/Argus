"""Destination-only bootstrap state handling. Raw state never leaves private files.

The CLI supplies verified account/bucket checks and holds account_lock for every
manager operation. This module never applies a plan, imports, or writes S3 itself.
"""
from contextlib import contextmanager
from dataclasses import dataclass
import datetime
import fcntl
import hashlib
import hmac
import json
import os
from pathlib import Path
import re
import socket
import stat
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
import xml.etree.ElementTree as ET


class BackendError(Exception):
    """Safe, constant diagnostic: callers must not print underlying exceptions."""


SOURCE_ACCOUNT = "5cc3bc33ca089258d20b6e80e67e5333"
_HELD_LOCKS = set()


@dataclass(frozen=True)
class BackendSpec:
    account: str
    target: str

    def __post_init__(self):
        if (not isinstance(self.account, str) or
                not re.fullmatch(r"[0-9a-f]{32}", self.account) or self.account == SOURCE_ACCOUNT):
            raise BackendError("A verified destination account is required.")
        if self.target not in ("bootstrap", "staging", "prod"):
            raise BackendError("An explicit destination target is required.")

    @property
    def endpoint(self):
        return f"https://{self.account}.r2.cloudflarestorage.com"

    @property
    def bucket(self):
        return f"ritual-investing-terraform-state-{'prod' if self.target == 'bootstrap' else self.target}"

    @property
    def key(self):
        return "bootstrap/terraform.tfstate" if self.target == "bootstrap" else "workloads/terraform.tfstate"

    def identity(self):
        return {"account": self.account, "target": self.target, "endpoint": self.endpoint,
                "bucket": self.bucket, "key": self.key}

    def configuration(self, key=None):
        # The sole key override is an internal disposable locking-check key.
        if key is not None and not re.fullmatch(r"locking-check/[0-9a-f]{32}/terraform.tfstate", key):
            raise BackendError("Invalid disposable backend key.")
        return {"bucket": self.bucket, "key": key or self.key, "region": "auto",
                "endpoints": {"s3": self.endpoint}, "encrypt": True,
                "use_lockfile": True, "use_path_style": True,
                "skip_credentials_validation": True, "skip_region_validation": True,
                "skip_requesting_account_id": True, "skip_metadata_api_check": True,
                "skip_s3_checksum": True}


def _private_directory(path):
    path = Path(path)
    if path.is_symlink():
        raise BackendError("Private storage must not be a symlink.")
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    info = path.stat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid():
        raise BackendError("Private storage must be an operator-owned directory.")
    path.chmod(0o700)
    return path.resolve()


def private_account_directory(account, base=None):
    BackendSpec(account, "bootstrap")
    base = Path(base) if base is not None else Path.home() / ".local/state/ritual-investing-destination/accounts"
    # Existing symlink ancestors could redirect recoverable state to shared storage.
    if any(parent.is_symlink() for parent in (base, *base.parents)):
        raise BackendError("Private storage must not traverse symlinks.")
    base = _private_directory(base)
    return _private_directory(base / account)


def private_write(path, data):
    """Atomically replace one private regular file and durably persist its bytes."""
    path = Path(path)
    parent = _private_directory(path.parent)
    if path.is_symlink() or (path.exists() and not path.is_file()):
        raise BackendError("Private artifacts must be regular files.")
    fd, temporary = tempfile.mkstemp(prefix=".pending-", dir=parent)
    try:
        with os.fdopen(fd, "wb") as output:
            output.write(data)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
        directory_fd = os.open(parent, os.O_RDONLY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def _json_bytes(value):
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode()


def _no_duplicates(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate key")
        result[key] = value
    return result


def _read_json(path):
    try:
        path = Path(path)
        if path.is_symlink() or not path.is_file():
            raise ValueError("not a regular file")
        return json.loads(path.read_bytes(), object_pairs_hook=_no_duplicates,
                          parse_constant=lambda value: (_ for _ in ()).throw(ValueError("nonfinite")))
    except (OSError, ValueError, TypeError):
        raise BackendError("A private state or metadata file is missing or invalid.") from None


@contextmanager
def account_lock(directory):
    directory = _private_directory(directory)
    lock_path = directory / "account.lock"
    try:
        fd = os.open(lock_path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    except OSError:
        raise BackendError("The account lock is unavailable.") from None
    try:
        os.fchmod(fd, 0o600)
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            raise BackendError("Another operator holds the account lock; retry after release.") from None
        _HELD_LOCKS.add(directory)
        try:
            yield directory
        finally:
            _HELD_LOCKS.discard(directory)
            fcntl.flock(fd, fcntl.LOCK_UN)
    finally:
        os.close(fd)


def _validate_state(value):
    if (not isinstance(value, dict) or value.get("version") != 4 or
            type(value.get("serial")) is not int or value["serial"] < 0 or
            not isinstance(value.get("lineage"), str) or not value["lineage"] or
            not isinstance(value.get("outputs"), dict) or
            not isinstance(value.get("resources"), list)):
        raise BackendError("Preserved Terraform state is invalid; recovery is required.")
    addresses = set()
    for resource in value["resources"]:
        if (not isinstance(resource, dict) or resource.get("mode") not in ("managed", "data") or
                not all(isinstance(resource.get(key), str) and resource[key] for key in ("type", "name", "provider")) or
                not isinstance(resource.get("instances"), list)):
            raise BackendError("Preserved Terraform state resources are invalid.")
        for instance in resource["instances"]:
            if not isinstance(instance, dict) or not isinstance(instance.get("attributes"), dict):
                raise BackendError("Preserved Terraform state instances are invalid.")
            index = instance.get("index_key")
            if index is not None and type(index) not in (str, int):
                raise BackendError("Preserved Terraform state addresses are invalid.")
            address = (resource.get("module", ""), resource["mode"], resource["type"], resource["name"], index)
            if address in addresses or instance.get("deposed") or instance.get("status") == "tainted":
                raise BackendError("Ambiguous or tainted state requires recovery.")
            addresses.add(address)
            if resource["mode"] == "managed" and not instance["attributes"].get("id"):
                raise BackendError("Preserved Terraform state has a missing resource ID.")
    return value


def read_state(path):
    return _validate_state(_read_json(path))


def states_match(left, right):
    # Compare the complete document, including lineage, serial, addresses and IDs.
    # JSON whitespace/key ordering are irrelevant; no state fields are discarded.
    return _json_bytes(_validate_state(left)) == _json_bytes(_validate_state(right))


def _bootstrap_inventory(value, spec):
    _validate_state(value)
    actual = {}
    for resource in value["resources"]:
        if (resource.get("module") or resource["mode"] != "managed" or
                resource["type"] != "cloudflare_r2_bucket" or resource["name"] != "state"):
            raise BackendError("Bootstrap state inventory is outside the destination contract.")
        for instance in resource["instances"]:
            attrs = instance["attributes"]
            key = instance.get("index_key")
            if key in actual or attrs.get("account_id") != spec.account:
                raise BackendError("Bootstrap state inventory or account is invalid.")
            actual[key] = attrs.get("name")
    expected = {target: f"ritual-investing-terraform-state-{target}" for target in ("prod", "staging")}
    if actual != expected:
        raise BackendError("Bootstrap state inventory is incomplete; recover the partial apply before migration.")


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class S3StateReader:
    """Read-only SigV4 GET. Credentials come only from the process environment."""

    @property
    def available(self):
        return bool(os.environ.get("AWS_ACCESS_KEY_ID") and os.environ.get("AWS_SECRET_ACCESS_KEY"))

    def get(self, spec, destination, key=None):
        if not self.available:
            raise BackendError("Destination R2 object credentials are required.")
        object_key = key or spec.key
        if object_key != spec.key and not re.fullmatch(
                r"locking-check/[0-9a-f]{32}/terraform.tfstate(?:\.tflock)?", object_key):
            raise BackendError("Refusing an unexpected state object key.")
        now = datetime.datetime.now(datetime.timezone.utc)
        stamp, day = now.strftime("%Y%m%dT%H%M%SZ"), now.strftime("%Y%m%d")
        host = urllib.parse.urlsplit(spec.endpoint).netloc
        path = urllib.parse.quote(f"/{spec.bucket}/{object_key}", safe="/-_.~")
        payload_hash = hashlib.sha256(b"").hexdigest()
        headers = {"host": host, "x-amz-content-sha256": payload_hash, "x-amz-date": stamp}
        token = os.environ.get("AWS_SESSION_TOKEN")
        if token:
            headers["x-amz-security-token"] = token
        signed = ";".join(sorted(headers))
        canonical_headers = "".join(f"{name}:{headers[name].strip()}\n" for name in sorted(headers))
        canonical = f"GET\n{path}\n\n{canonical_headers}\n{signed}\n{payload_hash}"
        scope = f"{day}/auto/s3/aws4_request"
        string_to_sign = f"AWS4-HMAC-SHA256\n{stamp}\n{scope}\n{hashlib.sha256(canonical.encode()).hexdigest()}"
        signing_key = ("AWS4" + os.environ["AWS_SECRET_ACCESS_KEY"]).encode()
        for part in (day, "auto", "s3", "aws4_request"):
            signing_key = hmac.new(signing_key, part.encode(), hashlib.sha256).digest()
        signature = hmac.new(signing_key, string_to_sign.encode(), hashlib.sha256).hexdigest()
        headers["Authorization"] = (f"AWS4-HMAC-SHA256 Credential={os.environ['AWS_ACCESS_KEY_ID']}/{scope}, "
                                    f"SignedHeaders={signed}, Signature={signature}")
        request = urllib.request.Request(spec.endpoint + path, headers=headers, method="GET")
        try:
            response = urllib.request.build_opener(_NoRedirect()).open(request, timeout=30)
            with response:
                data = response.read(64 * 1024 * 1024 + 1)
                if response.status != 200 or len(data) > 64 * 1024 * 1024:
                    raise BackendError("State object response is incomplete or invalid.")
                private_write(destination, data)
            return True
        except urllib.error.HTTPError as error:
            body = error.read(1024 * 1024)
            private_write(destination, body)
            if error.code == 404:
                try:
                    document = ET.fromstring(body)
                    codes = [element.text for element in document.iter() if element.tag.split("}")[-1] == "Code"]
                    if codes == ["NoSuchKey"]:
                        return False
                except ET.ParseError:
                    pass
            raise BackendError("State object read failed; absence or authority is unproven.") from None
        except (OSError, ValueError, urllib.error.URLError):
            raise BackendError("State object transport failed; retry without changing state.") from None


class TerraformCommand:
    """Terraform adapter: logs stay private; values never enter command arguments."""

    def __init__(self, binary="terraform", environment=None):
        self.binary = binary
        self.environment = dict(os.environ if environment is None else environment)
        # Wrapper preflight rejects unsafe overrides; the adapter also removes logs
        # and redirection so callers cannot accidentally send raw state elsewhere.
        for name in list(self.environment):
            if (name.startswith(("TF_LOG", "TF_CLI_ARGS", "AWS_ENDPOINT_URL")) or
                    name in ("TF_DATA_DIR", "TF_WORKSPACE", "TF_REATTACH_PROVIDERS")):
                del self.environment[name]
        self.environment.update(TF_IN_AUTOMATION="1", TF_INPUT="0", AWS_EC2_METADATA_DISABLED="true")
        self.last_output = None

    def start(self, args, cwd, label, *, allow_input=False):
        cwd = _private_directory(cwd)
        logs = _private_directory(cwd / "logs")
        self.last_output = logs / f"{label}-{uuid.uuid4().hex}.log"
        fd = os.open(self.last_output, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        environment = dict(self.environment)
        if allow_input:
            # A resource-free locking probe supplies its own nonsecret input to
            # release a plan blocked at Terraform's post-lock variable prompt.
            environment["TF_INPUT"] = "1"
            environment.pop("TF_IN_AUTOMATION", None)
        try:
            with os.fdopen(fd, "wb") as output:
                return subprocess.Popen([self.binary, *args], cwd=cwd, env=environment,
                                        stdin=subprocess.PIPE, stdout=output, stderr=subprocess.STDOUT,
                                        umask=0o077)
        except OSError:
            raise BackendError("Terraform could not start; private recovery artifacts are preserved.") from None

    def run(self, args, cwd, label):
        process = self.start(args, cwd, label)
        process.communicate()
        return process.returncode


def _write_backend(path, spec, key=None):
    # Terraform selects its JSON parser from the final .json extension.
    private_write(path, _json_bytes(spec.configuration(key)))


def verify_remote_locking(spec, directory, terraform, reader, timeout=25):
    """Prove Terraform lock contention and clean release using an empty backend.

    Terraform plan prompts for a required variable after acquiring its backend
    lock (Terraform 1.15 internal/backend/local/backend_local.go). Supplying that
    variable lets the resource-free plan finish normally. Only Terraform creates
    or deletes locks; signed GET observes the holder during both contenders.
    """
    probe = _private_directory(Path(directory) / "locking-checks" / uuid.uuid4().hex)
    key = f"locking-check/{uuid.uuid4().hex}/terraform.tfstate"
    private_write(probe / "main.tf", b'terraform {\n  required_version = "~> 1.15.0"\n  backend "s3" {}\n}\nvariable "lock_probe" {\n  type = string\n}\n')
    _write_backend(probe / "backend.tfbackend.json", spec, key)
    if terraform.run(["init", "-input=false", "-no-color", "-backend-config=backend.tfbackend.json"], probe, "lock-init") != 0:
        raise BackendError("Remote locking initialization failed; preserve the private probe for recovery.")
    holder = terraform.start(["plan", "-input=true", "-no-color", "-lock-timeout=0s"],
                             probe, "lock-holder", allow_input=True)
    observed = probe / "observed-lock.json"
    lock_id = None
    failed = False
    try:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if holder.poll() is not None:
                raise BackendError("Remote locking holder failed before lock observation.")
            if reader.get(spec, observed, key + ".tflock"):
                lock = _read_json(observed)
                if (not isinstance(lock, dict) or not isinstance(lock.get("ID"), str) or not lock["ID"] or
                        lock.get("Path") != f"{spec.bucket}/{key}"):
                    raise BackendError("Remote locking returned an unexpected lock identity.")
                lock_id = lock["ID"]
                break
            time.sleep(0.2)
        if lock_id is None:
            raise BackendError("Remote locking was not observed before timeout.")
        code = terraform.run(["plan", "-input=false", "-no-color", "-lock-timeout=0s", "-var=lock_probe=check"], probe, "lock-contender")
        output = terraform.last_output.read_bytes()
        if code != 1 or b"Error acquiring the state lock" not in output or lock_id.encode() not in output:
            raise BackendError("Remote locking did not reject the second Terraform contender.")
        if holder.poll() is not None or not reader.get(spec, observed, key + ".tflock") or _read_json(observed).get("ID") != lock_id:
            raise BackendError("Remote locking holder changed during contention verification.")
    except BaseException:
        failed = True
        raise
    finally:
        # Satisfy the held plan's input, allowing normal completion and unlock.
        # This is a fixed, nonsecret probe value, not a user prompt.
        if holder.stdin and not holder.stdin.closed:
            try:
                holder.stdin.write(b"complete\n")
                holder.stdin.close()
            except BrokenPipeError:
                pass
        try:
            holder.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            holder.terminate()
            try:
                holder.wait(timeout=5)
            except subprocess.TimeoutExpired:
                holder.kill()
                holder.wait()
            if not failed:
                raise BackendError("Remote locking holder did not release cleanly; manual recovery is required.") from None
    if holder.returncode != 0 or reader.get(spec, observed, key + ".tflock"):
        raise BackendError("Remote locking release was not verified; do not force-unlock.")
    if terraform.run(["plan", "-input=false", "-no-color", "-lock-timeout=0s", "-detailed-exitcode", "-var=lock_probe=check"], probe, "lock-after-release") != 0:
        raise BackendError("Remote locking could not be reacquired after release.")
    if reader.get(spec, observed, key + ".tflock"):
        raise BackendError("Remote locking left a lock after the final contender.")
    private_write(probe / "verified.json", _json_bytes({"backend": spec.identity(), "probe_key": key,
                                                       "verified_at": datetime.datetime.now(datetime.timezone.utc).isoformat()}))
    return True


class BootstrapManager:
    """Preserve a bootstrap snapshot and migrate only proven identical state.

    Lifecycle: prepare -> CLI plan -> consume_plan -> CLI apply ->
    record_apply_result -> resume. Resume never invokes apply or reads checkout
    configuration. All methods require an account_lock and the designated host.
    """

    def __init__(self, spec, directory, terraform, reader, verify_buckets, verify_locking,
                 designated_host=None):
        if spec.target != "bootstrap":
            raise BackendError("Bootstrap manager requires the bootstrap target.")
        self.spec = spec
        self.directory = _private_directory(directory)
        if self.directory.name != spec.account:
            raise BackendError("Bootstrap recovery directory does not match the destination account.")
        self.terraform = terraform
        self.reader = reader
        self.verify_buckets = verify_buckets
        self.verify_locking = verify_locking
        self.designated_host = designated_host
        self.workdir = self.directory / "work"
        self.snapshot = self.directory / "snapshot"
        self.phase_path = self.directory / "phase.json"

    def _guard(self):
        if self.directory not in _HELD_LOCKS:
            raise BackendError("Hold the account lock before a bootstrap operation.")
        if not self.designated_host or self.designated_host != socket.gethostname():
            raise BackendError("Bootstrap requires its explicitly designated host.")
        if any(self.directory.rglob("errored.tfstate")):
            raise BackendError("An emergency Terraform state exists; explicit recovery is required.")

    def _save(self, phase):
        private_write(self.phase_path, _json_bytes(phase))

    def status(self):
        phase = _read_json(self.phase_path)
        if not isinstance(phase, dict) or phase.get("backend") != self.spec.identity():
            raise BackendError("Bootstrap phase account/backend identity is invalid.")
        return phase

    def _snapshot_digest(self):
        digest = hashlib.sha256()
        for path in sorted(self.snapshot.iterdir()):
            if path.is_symlink() or not path.is_file():
                raise BackendError("Bootstrap snapshot contains an unexpected path.")
            digest.update(path.name.encode() + b"\0" + path.read_bytes() + b"\0")
        return digest.hexdigest()

    def _preserved(self):
        phase = self.status()
        if phase.get("designated_host") != self.designated_host:
            raise BackendError("Bootstrap recovery must remain on its recorded designated host.")
        if not self.snapshot.is_dir() or phase.get("snapshot_sha256") != self._snapshot_digest():
            raise BackendError("Bootstrap snapshot changed; recovery is required.")
        # Only backend.tf intentionally changes when staging remote configuration.
        for source in self.snapshot.iterdir():
            if source.name == "backend.tf":
                continue
            destination = self.workdir / source.name
            if destination.is_symlink() or not destination.is_file() or destination.read_bytes() != source.read_bytes():
                raise BackendError("Bootstrap working configuration changed; recovery is required.")
        known = {path.name for path in self.snapshot.iterdir()} | {"backend.tf", "backend.tfbackend.json"}
        if any(path.name not in known for path in self.workdir.iterdir()
               if path.name.endswith((".tf", ".tf.json", ".tfvars", ".tfvars.json"))):
            raise BackendError("Bootstrap working configuration has unexpected Terraform inputs.")
        return phase

    def prepare(self, source_root, revision):
        self._guard()
        if self.phase_path.exists():
            return self._preserved()
        if any(self.directory.glob("*.tfstate*")) or self.workdir.exists() or self.snapshot.exists():
            raise BackendError("Existing bootstrap recovery artifacts require recovery, not fresh local state.")
        if not isinstance(revision, str) or not re.fullmatch(r"[0-9a-f]{40,64}", revision):
            raise BackendError("A checked-in snapshot revision is required.")
        _private_directory(self.snapshot)
        _private_directory(self.workdir)
        source_root = Path(source_root)
        for source in sorted(source_root.iterdir()):
            if source.name.endswith(".tf") or source.name in (".terraform.lock.hcl", "backend.hcl", "backend.remote.tf.template"):
                if source.is_symlink() or not source.is_file():
                    raise BackendError("Bootstrap inputs must be regular files.")
                private_write(self.snapshot / source.name, source.read_bytes())
                private_write(self.workdir / source.name, source.read_bytes())
        if not (self.snapshot / "backend.remote.tf.template").is_file() or not (self.snapshot / "backend.tf").is_file():
            raise BackendError("Bootstrap backend templates are missing.")
        phase = {"schema_version": 1, "stage": "LocalPrepared", "revision": revision,
                 "backend": self.spec.identity(), "snapshot_sha256": self._snapshot_digest(),
                 "plan_consumed": False, "designated_host": self.designated_host}
        self._save(phase)
        return phase

    def initialize_local(self):
        self._guard()
        phase = self._preserved()
        if phase["stage"] != "LocalPrepared" or phase["plan_consumed"]:
            raise BackendError("Local initialization cannot replay a consumed bootstrap plan.")
        if self.terraform.run(["init", "-input=false", "-no-color", "-lockfile=readonly"], self.workdir, "bootstrap-local-init") != 0:
            raise BackendError("Local bootstrap initialization failed; recovery artifacts are preserved.")

    def consume_plan(self, plan_sha256):
        self._guard()
        phase = self._preserved()
        if phase["plan_consumed"]:
            raise BackendError("The bootstrap plan is consumed; resume preserved state without replaying apply.")
        if not re.fullmatch(r"[0-9a-f]{64}", plan_sha256):
            raise BackendError("A validated saved-plan digest is required.")
        phase.update(stage="Applying", plan_consumed=True, plan_sha256=plan_sha256)
        self._save(phase)

    def record_apply_result(self, returncode):
        self._guard()
        phase = self._preserved()
        if not phase["plan_consumed"]:
            raise BackendError("A bootstrap apply must consume its saved plan first.")
        local_path = self.workdir / "terraform.tfstate"
        if local_path.exists():
            local = read_state(local_path)
            private_write(self.directory / "authoritative-local.tfstate", _json_bytes(local))
        else:
            phase["stage"] = "RecoveryRequired"
            self._save(phase)
            raise BackendError("Bootstrap apply left no normal state; preserve artifacts for recovery.")
        phase["stage"] = "BucketsCreated" if returncode == 0 else "RecoveryRequired"
        self._save(phase)

    def resume(self):
        self._guard()
        phase = self._preserved()
        if not phase["plan_consumed"]:
            raise BackendError("Bootstrap has no consumed bucket-creation plan to resume.")
        authority_path = self.directory / "authoritative-local.tfstate"
        if not authority_path.exists():
            # An interruption can happen after Terraform writes state but before
            # record_apply_result. The preserved work state is then the only source.
            local = read_state(self.workdir / "terraform.tfstate")
            private_write(authority_path, _json_bytes(local))
        authority = read_state(authority_path)
        _bootstrap_inventory(authority, self.spec)
        normal = self.workdir / "terraform.tfstate"
        if normal.exists() and not states_match(authority, read_state(normal)):
            raise BackendError("Local state is divergent from the preserved authority; explicit recovery is required.")
        if not self.reader.available:
            phase["stage"] = "AwaitingBackendCredentials"
            self._save(phase)
            return phase
        if self.verify_buckets(self.spec) is not True:
            raise BackendError("Destination state bucket ownership is unverified.")
        remote_path = self.directory / "remote-readback.tfstate"
        remote_exists = self.reader.get(self.spec, remote_path)
        if remote_exists and not states_match(authority, read_state(remote_path)):
            raise BackendError("Remote state is divergent; automatic overwrite is forbidden.")
        private_write(self.workdir / "backend.tf", (self.snapshot / "backend.remote.tf.template").read_bytes())
        _write_backend(self.workdir / "backend.tfbackend.json", self.spec)
        if remote_exists:
            # Matching remote authority already exists. Reconnect without copying.
            args = ["init", "-input=false", "-no-color", "-lockfile=readonly", "-reconfigure", "-backend-config=backend.tfbackend.json"]
        else:
            private_write(normal, _json_bytes(authority))
            # Reset only Terraform's backend metadata to local. This handles an
            # interrupted previous init without resetting or deleting any state.
            private_write(self.workdir / "backend.tf", (self.snapshot / "backend.tf").read_bytes())
            if self.terraform.run(["init", "-input=false", "-no-color", "-lockfile=readonly", "-reconfigure"], self.workdir, "bootstrap-local-reconnect") != 0:
                raise BackendError("Local state reconnect failed; preserved state remains authoritative.")
            private_write(self.workdir / "backend.tf", (self.snapshot / "backend.remote.tf.template").read_bytes())
            # Recheck immediately before the only command allowed to copy state.
            if self.reader.get(self.spec, remote_path):
                raise BackendError("Remote state appeared before migration; resume to compare authority.")
            args = ["init", "-input=false", "-no-color", "-lockfile=readonly", "-migrate-state", "-force-copy", "-backend-config=backend.tfbackend.json"]
        phase["stage"] = "RecoveryRequired"
        self._save(phase)
        if self.terraform.run(args, self.workdir, "bootstrap-remote-init") != 0:
            raise BackendError("Bootstrap migration or reconnect failed; resume from preserved state.")
        self._guard()
        if not self.reader.get(self.spec, remote_path) or not states_match(authority, read_state(remote_path)):
            raise BackendError("Remote state read-back failed or is divergent; preserve all recovery artifacts.")
        phase["stage"] = "MigrationVerified"
        self._save(phase)
        if self.verify_locking(self.spec, self.directory) is not True:
            raise BackendError("Remote locking verification failed; bootstrap remains incomplete.")
        phase["stage"] = "RemoteReady"
        self._save(phase)
        return phase
