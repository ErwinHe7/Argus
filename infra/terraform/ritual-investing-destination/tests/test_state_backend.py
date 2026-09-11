"""Offline state-authority contracts; no credentials or remote services."""
import io
import json
import os
from pathlib import Path
import socket
import signal
import subprocess
import sys
import tempfile
import time
import urllib.error
import unittest
from unittest.mock import Mock, call, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from state_backend import (BackendError, BackendSpec, BootstrapManager,
                           S3StateReader, account_lock, private_account_directory,
                           TerraformCommand, private_write, read_state, states_match, verify_remote_locking)

ACCOUNT = "1" * 32
REVISION = "a" * 40


def state(serial=1):
    return {"version": 4, "terraform_version": "1.15.0", "serial": serial,
            "lineage": "11111111-2222-3333-4444-555555555555", "outputs": {},
            "resources": [{"mode": "managed", "type": "cloudflare_r2_bucket",
                           "name": "state", "provider": 'provider["registry.terraform.io/cloudflare/cloudflare"]',
                           "instances": [{"index_key": target, "schema_version": 0,
                                          "attributes": {"id": f"bucket-{target}", "account_id": ACCOUNT,
                                                         "name": f"ritual-investing-terraform-state-{target}"}}
                                         for target in ("prod", "staging")]}]}


class Reader:
    available = True

    def __init__(self):
        self.remote = None

    def get(self, spec, destination, key=None):
        if self.remote is None:
            return False
        private_write(destination, json.dumps(self.remote).encode())
        return True


class Terraform:
    def __init__(self, reader):
        self.calls = []
        self.reader = reader
        self.fail_migration = False

    def run(self, args, cwd, label):
        self.calls.append(tuple(args))
        if "-migrate-state" in args:
            self.reader.remote = read_state(cwd / "terraform.tfstate")
            if self.fail_migration:
                return 1
        return 0


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name).resolve()
        self.source = self.base / "source"
        self.source.mkdir()
        private_write(self.source / "main.tf", b'resource "cloudflare_r2_bucket" "state" {}')
        private_write(self.source / "backend.tf", b'terraform { backend "local" {} }')
        private_write(self.source / "backend.remote.tf.template", b'terraform { backend "s3" {} }')
        self.directory = private_account_directory(ACCOUNT, self.base / "recovery")
        self.reader = Reader()
        self.tf = Terraform(self.reader)
        self.owned = True
        self.locked = True
        self.manager = BootstrapManager(BackendSpec(ACCOUNT, "bootstrap"), self.directory,
                                        self.tf, self.reader, lambda spec: self.owned,
                                        lambda spec, directory: self.locked,
                                        designated_host=socket.gethostname())
        self.lock_context = account_lock(self.directory)
        self.lock_context.__enter__()
        self.addCleanup(self.lock_context.__exit__, None, None, None)
        self.manager.prepare(self.source, REVISION)

    def created(self):
        self.manager.consume_plan("b" * 64)
        private_write(self.manager.workdir / "terraform.tfstate", json.dumps(state()).encode())
        self.manager.record_apply_result(0)

    def test_fresh_bootstrap_migrates_once_and_verifies_remote(self):
        self.created()
        result = self.manager.resume()
        self.assertEqual(result["stage"], "RemoteReady")
        self.assertEqual(result["revision"], REVISION)
        self.assertTrue(states_match(state(), self.reader.remote))
        self.assertEqual(sum("-migrate-state" in args for args in self.tf.calls), 1)
        self.assertTrue((self.directory / "authoritative-local.tfstate").exists())

    def test_missing_credentials_preserves_state_and_consumed_plan(self):
        self.created()
        self.reader.available = False
        result = self.manager.resume()
        self.assertEqual(result["stage"], "AwaitingBackendCredentials")
        self.assertTrue((self.directory / "authoritative-local.tfstate").exists())
        with self.assertRaisesRegex(BackendError, "consumed"):
            self.manager.consume_plan("b" * 64)

    def test_resume_uses_original_snapshot_after_checkout_changes(self):
        self.created()
        private_write(self.source / "main.tf", b"changed checkout")
        result = self.manager.resume()
        self.assertEqual(result["revision"], REVISION)
        self.assertNotEqual((self.manager.workdir / "main.tf").read_bytes(), b"changed checkout")
        self.assertFalse(any("apply" in args for args in self.tf.calls))

    def test_interruption_after_remote_copy_reconnects_without_copying_again(self):
        self.created()
        self.tf.fail_migration = True
        with self.assertRaises(BackendError):
            self.manager.resume()
        self.manager.resume()
        self.assertEqual(sum("-migrate-state" in args for args in self.tf.calls), 1)
        self.assertTrue(any("-reconfigure" in args for args in self.tf.calls))

    def test_remote_copy_without_completion_marker_is_authoritative(self):
        self.created()
        self.reader.remote = state()
        (self.manager.workdir / "terraform.tfstate").unlink()
        self.assertEqual(self.manager.resume()["stage"], "RemoteReady")
        self.assertFalse(any("-migrate-state" in args for args in self.tf.calls))

    def test_divergent_remote_lineage_serial_ids_or_contents_never_overwritten(self):
        self.created()
        variants = [state(2), state(), state(), state()]
        variants[1]["lineage"] = "different-lineage"
        variants[2]["resources"][0]["instances"][0]["attributes"]["id"] = "different-id"
        variants[3]["outputs"] = {"unexpected": {"value": "changed", "type": "string"}}
        for remote in variants:
            with self.subTest(remote=variants.index(remote)):
                self.reader.remote = remote
                with self.assertRaisesRegex(BackendError, "divergent"):
                    self.manager.resume()
        self.assertFalse(any("-migrate-state" in args for args in self.tf.calls))

    def test_emergency_state_refuses_older_normal_state(self):
        self.created()
        private_write(self.manager.workdir / "errored.tfstate", json.dumps(state(2)).encode())
        with self.assertRaisesRegex(BackendError, "emergency"):
            self.manager.resume()
        with self.assertRaisesRegex(BackendError, "emergency"):
            self.manager.prepare(self.source, REVISION)

    def test_partial_create_preserves_state_but_cannot_migrate_incomplete_inventory(self):
        self.manager.consume_plan("b" * 64)
        partial = state()
        partial["resources"][0]["instances"].pop()
        private_write(self.manager.workdir / "terraform.tfstate", json.dumps(partial).encode())
        self.manager.record_apply_result(1)
        self.assertTrue((self.directory / "authoritative-local.tfstate").exists())
        with self.assertRaisesRegex(BackendError, "inventory"):
            self.manager.resume()

    def test_partial_apply_can_replan_same_snapshot_without_replaying_old_plan(self):
        self.manager.consume_plan("b" * 64)
        partial = state()
        partial["resources"][0]["instances"].pop()
        private_write(self.manager.workdir / "terraform.tfstate", json.dumps(partial).encode())
        self.manager.record_apply_result(1)
        self.manager.prepare_replan(REVISION)
        self.manager.initialize_local()
        with self.assertRaises(BackendError):
            self.manager.consume_plan("b" * 64)
        self.manager.consume_plan("c" * 64)
        self.assertEqual(self.manager.status()["stage"], "Applying")
        self.assertTrue(states_match(partial, read_state(self.manager.workdir / "terraform.tfstate")))

    def test_missing_authority_does_not_start_fresh(self):
        self.created()
        (self.directory / "authoritative-local.tfstate").unlink()
        (self.manager.workdir / "terraform.tfstate").unlink()
        with self.assertRaisesRegex(BackendError, "state"):
            self.manager.resume()

    def test_interrupted_apply_uses_preserved_work_state_without_replaying_plan(self):
        self.manager.consume_plan("b" * 64)
        private_write(self.manager.workdir / "terraform.tfstate", json.dumps(state()).encode())
        self.assertEqual(self.manager.resume()["stage"], "RemoteReady")
        self.assertFalse(any("apply" in args for args in self.tf.calls))

    def test_changed_snapshot_or_extra_working_configuration_stops_resume(self):
        self.created()
        private_write(self.manager.workdir / "unsafe.auto.tfvars", b"unreviewed=true")
        with self.assertRaisesRegex(BackendError, "unexpected"):
            self.manager.resume()
        (self.manager.workdir / "unsafe.auto.tfvars").unlink()
        private_write(self.manager.snapshot / "main.tf", b"tampered snapshot")
        with self.assertRaisesRegex(BackendError, "snapshot"):
            self.manager.resume()

    def test_bucket_ownership_or_locking_failure_cannot_report_ready(self):
        self.created()
        self.owned = False
        with self.assertRaisesRegex(BackendError, "ownership"):
            self.manager.resume()
        self.owned = True
        self.locked = False
        with self.assertRaisesRegex(BackendError, "locking"):
            self.manager.resume()
        self.assertNotEqual(self.manager.status()["stage"], "RemoteReady")

    def test_another_local_operator_cannot_take_account_lock(self):
        with self.assertRaisesRegex(BackendError, "lock"):
            with account_lock(self.directory):
                self.fail("second lock acquired")

    def test_wrong_designated_host_fails_before_local_preparation(self):
        self.manager.designated_host = "another-host.invalid"
        with self.assertRaisesRegex(BackendError, "host"):
            self.manager.prepare(self.source, REVISION)

    def test_private_artifacts_and_symlinks(self):
        self.assertEqual(self.directory.stat().st_mode & 0o777, 0o700)
        self.assertEqual((self.directory / "phase.json").stat().st_mode & 0o777, 0o600)
        destination = self.base / "link"
        destination.symlink_to(self.base / "elsewhere")
        with self.assertRaises(BackendError):
            private_account_directory(ACCOUNT, destination)


class ValidationTests(unittest.TestCase):
    def test_backend_spec_has_fixed_account_https_endpoint_and_keys(self):
        spec = BackendSpec(ACCOUNT, "bootstrap")
        self.assertEqual(spec.endpoint, f"https://{ACCOUNT}.r2.cloudflarestorage.com")
        self.assertEqual(spec.bucket, "ritual-investing-terraform-state-prod")
        self.assertEqual(spec.key, "bootstrap/terraform.tfstate")
        self.assertEqual(BackendSpec(ACCOUNT, "staging").key, "workloads/terraform.tfstate")
        for account, target in [(None, "prod"), ("5cc3bc33ca089258d20b6e80e67e5333", "prod"),
                                (ACCOUNT, "personal"), ("https://bad", "prod")]:
            with self.assertRaises(BackendError):
                BackendSpec(account, target)

    def test_state_comparison_is_order_independent_but_not_lossy(self):
        self.assertTrue(states_match(state(), json.loads(json.dumps(state(), sort_keys=True))))
        self.assertFalse(states_match(state(), state(2)))
        for malformed in ({}, {**state(), "serial": True}, {**state(), "lineage": ""},
                          {**state(), "resources": None}):
            with self.assertRaises(BackendError):
                states_match(state(), malformed)

    def test_state_reader_requires_environment_credentials(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertFalse(S3StateReader().available)

    def test_signed_get_keeps_credentials_in_headers_and_writes_private_response(self):
        class Response(io.BytesIO):
            status = 200
        with tempfile.TemporaryDirectory() as folder:
            destination = Path(folder).resolve() / "response"
            with patch.dict(os.environ, {"AWS_ACCESS_KEY_ID": "synthetic-access-key",
                                         "AWS_SECRET_ACCESS_KEY": "synthetic-secret-key"}, clear=True):
                with patch("urllib.request.OpenerDirector.open", return_value=Response(b"private-state")) as request:
                    self.assertTrue(S3StateReader().get(BackendSpec(ACCOUNT, "bootstrap"), destination))
                    argument = request.call_args.args[0]
                    self.assertEqual(argument.method, "GET")
                    self.assertEqual(argument.full_url,
                                     f"https://{ACCOUNT}.r2.cloudflarestorage.com/ritual-investing-terraform-state-prod/bootstrap/terraform.tfstate")
                    self.assertIn("AWS4-HMAC-SHA256 Credential=synthetic-access-key/", argument.headers["Authorization"])
                    self.assertNotIn("synthetic-secret-key", repr(argument.headers))
                    self.assertEqual(destination.stat().st_mode & 0o777, 0o600)

    def test_only_explicit_no_such_key_means_remote_absence(self):
        with tempfile.TemporaryDirectory() as folder:
            destination = Path(folder).resolve() / "response"
            for code, body, absent in [(404, b"<Error><Code>NoSuchKey</Code></Error>", True),
                                       (404, b"<Error><Code>NoSuchBucket</Code></Error>", False),
                                       (404, b"not xml", False),
                                       (403, b"<Error><Code>AccessDenied</Code></Error>", False),
                                       (301, b"redirect", False)]:
                with self.subTest(code=code, body=body):
                    error = urllib.error.HTTPError("https://redacted.invalid", code, "safe", {}, io.BytesIO(body))
                    with patch.dict(os.environ, {"AWS_ACCESS_KEY_ID": "synthetic-access-key",
                                                 "AWS_SECRET_ACCESS_KEY": "synthetic-secret-key"}, clear=True):
                        with patch("urllib.request.OpenerDirector.open", side_effect=error):
                            if absent:
                                self.assertFalse(S3StateReader().get(BackendSpec(ACCOUNT, "bootstrap"), destination))
                            else:
                                with self.assertRaises(BackendError):
                                    S3StateReader().get(BackendSpec(ACCOUNT, "bootstrap"), destination)
                    self.assertEqual(destination.read_bytes(), body)

    @unittest.skipUnless(os.environ.get("TEST_TERRAFORM_BIN"), "optional actual Terraform local-backend parser check")
    def test_actual_terraform_accepts_json_backend_configuration_and_private_logs(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            private_write(root / "main.tf", b'terraform {\n  backend "local" {}\n}\n')
            private_write(root / "backend.tfbackend.json", b'{"path":"terraform.tfstate"}')
            terraform = TerraformCommand(os.environ["TEST_TERRAFORM_BIN"])
            self.assertEqual(terraform.run(["init", "-input=false", "-backend-config=backend.tfbackend.json"],
                                           root, "local-parser-check"), 0)
            self.assertEqual(terraform.last_output.stat().st_mode & 0o777, 0o600)
            self.assertEqual((root / ".terraform").stat().st_mode & 0o777, 0o700)

    @unittest.skipUnless(os.environ.get("TEST_TERRAFORM_BIN"), "optional actual Terraform plan locking check")
    def test_actual_plan_holds_lock_and_normal_completion_releases_it(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            private_write(root / "main.tf", b'terraform {\n  backend "local" {}\n}\nvariable "lock_probe" {\n  type = string\n}\n')
            terraform = TerraformCommand(os.environ["TEST_TERRAFORM_BIN"])
            self.assertEqual(terraform.run(["init", "-input=false"], root, "local-lock-init"), 0)
            holder = terraform.start(["plan", "-input=true", "-no-color", "-lock-timeout=0s"],
                                     root, "local-lock-holder", allow_input=True)
            try:
                deadline = time.monotonic() + 5
                lock = root / ".terraform.tfstate.lock.info"
                while not lock.exists() and holder.poll() is None and time.monotonic() < deadline:
                    time.sleep(0.05)
                self.assertTrue(lock.exists())
                lock_id = json.loads(lock.read_bytes())["ID"]
                self.assertEqual(terraform.run(["plan", "-input=false", "-no-color", "-lock-timeout=0s", "-var=lock_probe=check"],
                                               root, "local-lock-contender"), 1)
                self.assertIn(b"Error acquiring the state lock", terraform.last_output.read_bytes())
                self.assertIn(lock_id.encode(), terraform.last_output.read_bytes())
                self.assertIsNone(holder.poll())
            finally:
                holder.stdin.write(b"complete\n")
                holder.stdin.close()
                holder.wait(timeout=5)
            self.assertEqual(holder.returncode, 0)
            self.assertFalse(lock.exists())
            self.assertEqual(terraform.run(["plan", "-input=false", "-no-color", "-lock-timeout=0s", "-var=lock_probe=check"],
                                           root, "local-lock-after-release"), 0)


class RemoteLockFailureTests(unittest.TestCase):
    def probe(self, root, failure):
        class Holder:
            def __init__(self):
                self.stdin = io.BytesIO()
                self.returncode = 1 if failure == "early_exit" else None
                self.waits, self.terminated, self.killed = 0, False, False

            def poll(self):
                return self.returncode

            def wait(self, timeout=None):
                self.waits += 1
                if failure == "interrupt_cleanup":
                    signal.raise_signal(signal.SIGINT)
                if ("timeout" in failure or "kill" in failure) and self.waits == 1:
                    raise subprocess.TimeoutExpired("synthetic-holder", timeout)
                if "kill" in failure and self.waits == 2:
                    raise subprocess.TimeoutExpired("synthetic-holder", timeout)
                if self.returncode is None:
                    self.returncode = 0
                return self.returncode

            def terminate(self):
                self.terminated = True
                if "kill" not in failure:
                    self.returncode = -15

            def kill(self):
                self.killed, self.returncode = True, -9

        holder = Holder()

        class Adapter:
            last_output = None
            reacquired = False
            calls = []

            def run(self, args, cwd, label):
                self.calls.append(args)
                self.last_output = cwd / (label + ".log")
                private_write(self.last_output, b"Error acquiring the state lock fixture-lock")
                if label == "lock-contender":
                    return 0 if failure == "contender" else 1
                if label == "lock-after-release":
                    self.reacquired = True
                    return 1 if failure == "reacquire" else 0
                return 0

            def start(self, *args, **kwargs):
                return holder

        adapter = Adapter()

        class LockReader:
            reads = 0

            def get(self, spec, destination, key):
                self.reads += 1
                if holder.returncode is not None and failure != "retained" and not (failure == "final_retained" and adapter.reacquired):
                    return False
                identifier = None if "malformed" in failure else "changed" if failure == "changed" and self.reads > 1 else "fixture-lock"
                private_write(destination, json.dumps({"ID": identifier, "Path": spec.bucket + "/" + key.removesuffix(".tflock")}).encode())
                return True

        return holder, adapter, LockReader()

    def test_failed_lock_proofs_reap_holders_and_never_record_success(self):
        cases = {"early_exit": "holder failed before lock observation",
                 "malformed": "unexpected lock identity", "changed": "holder changed",
                 "contender": "did not reject", "timeout": "did not release cleanly",
                 "kill": "did not release cleanly", "malformed_kill": "unexpected lock identity",
                 "retained": "release was not verified", "reacquire": "could not be reacquired",
                 "final_retained": "left a lock", "not_observed": "not observed before timeout"}
        for failure, message in cases.items():
            with self.subTest(failure=failure), tempfile.TemporaryDirectory() as folder:
                root = Path(folder).resolve()
                holder, adapter, reader = self.probe(root, failure)
                with self.assertRaisesRegex(BackendError, message):
                    verify_remote_locking(BackendSpec(ACCOUNT, "bootstrap"), root, adapter, reader,
                                          timeout=0 if failure == "not_observed" else 1)
                self.assertIsNotNone(holder.returncode)
                self.assertTrue(holder.stdin.closed)
                self.assertGreater(holder.waits, 0)
                self.assertEqual(holder.terminated, "timeout" in failure or "kill" in failure)
                self.assertEqual(holder.killed, "kill" in failure)
                self.assertEqual(list(root.rglob("verified.json")), [])
                self.assertFalse(any("force-unlock" in call for call in adapter.calls))

    def test_complete_lock_proof_records_success_after_reacquisition(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            holder, adapter, reader = self.probe(root, "")
            self.assertTrue(verify_remote_locking(BackendSpec(ACCOUNT, "bootstrap"), root, adapter, reader))
            self.assertTrue(adapter.reacquired)
            self.assertEqual(holder.returncode, 0)
            self.assertEqual(len(list(root.rglob("verified.json"))), 1)

    def test_interrupt_during_lock_cleanup_is_delivered_after_reaping(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            holder, adapter, reader = self.probe(root, "interrupt_cleanup")
            with self.assertRaises(KeyboardInterrupt):
                verify_remote_locking(BackendSpec(ACCOUNT, "bootstrap"), root, adapter, reader)
            self.assertEqual(holder.returncode, 0)
            self.assertTrue(holder.stdin.closed)
            self.assertEqual(list(root.rglob("verified.json")), [])


class ProcessOwnershipTests(unittest.TestCase):
    def test_stubborn_cancelled_process_group_is_stopped_and_reaped(self):
        process = Mock(pid=12345, stdin=io.BytesIO())
        process.communicate.side_effect = KeyboardInterrupt
        process.poll.return_value = None
        process.wait.side_effect = [subprocess.TimeoutExpired("synthetic", 30),
                                    subprocess.TimeoutExpired("synthetic", 5), -9]
        previous = {sig: signal.getsignal(sig) for sig in (signal.SIGINT, signal.SIGTERM)}
        command = TerraformCommand()
        with patch.object(command, "start", return_value=process), patch("state_backend.os.killpg") as kill_group:
            with self.assertRaises(KeyboardInterrupt):
                command.run(["apply"], Path("unused"), "cancel-check")
        process.send_signal.assert_called_once_with(signal.SIGINT)
        self.assertEqual(kill_group.call_args_list, [call(12345, signal.SIGTERM), call(12345, signal.SIGKILL)])
        self.assertEqual(process.wait.call_count, 3)
        self.assertTrue(process.stdin.closed)
        self.assertEqual({sig: signal.getsignal(sig) for sig in previous}, previous)

    def test_interrupt_reaps_child_before_account_lock_is_released(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            directory = private_account_directory(ACCOUNT, root / "accounts")
            child_code = f'''
import os, signal, sys, time
from pathlib import Path
root = Path({str(root)!r})
def stop(*args):
    (root / "stopping").touch()
    while not (root / "release").exists():
        time.sleep(0.01)
    (root / "saved-state").write_text("preserved")
    sys.exit(130)
signal.signal(signal.SIGINT, stop)
(root / "child-pid").write_text(str(os.getpid()))
while True:
    time.sleep(0.01)
'''
            driver_code = f'''
import sys
from pathlib import Path
sys.path.insert(0, {str(Path(__file__).resolve().parents[1])!r})
from state_backend import account_lock, TerraformCommand
try:
    with account_lock(Path({str(directory)!r})):
        TerraformCommand(sys.executable).run(["-c", {child_code!r}], Path({str(directory)!r}), "cancel-check")
except KeyboardInterrupt:
    sys.exit(1)
'''
            driver = subprocess.Popen([sys.executable, "-c", driver_code], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            child_pid = None

            def wait_for(path):
                deadline = time.monotonic() + 5
                while not path.exists() and time.monotonic() < deadline:
                    time.sleep(0.01)
                self.assertTrue(path.exists(), path.name)

            try:
                wait_for(root / "child-pid")
                child_pid = int((root / "child-pid").read_text())
                driver.send_signal(signal.SIGINT)
                wait_for(root / "stopping")
                driver.send_signal(signal.SIGINT)  # Cleanup must retain ownership on another interrupt.
                time.sleep(0.05)
                self.assertIsNone(driver.poll())
                with self.assertRaises(BackendError):
                    with account_lock(directory):
                        pass
                (root / "release").touch()
                driver.communicate(timeout=5)
                self.assertEqual(driver.returncode, 1)
                with self.assertRaises(ProcessLookupError):
                    os.kill(child_pid, 0)
                with account_lock(directory):
                    self.assertEqual((root / "saved-state").read_text(), "preserved")
                self.assertTrue(list((directory / "logs").glob("*.log")))
            finally:
                (root / "release").touch()
                if child_pid:
                    try:
                        os.kill(child_pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                if driver.poll() is None:
                    driver.kill()
                driver.communicate(timeout=5)


if __name__ == "__main__":
    unittest.main()
