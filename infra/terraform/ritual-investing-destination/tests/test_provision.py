"""Invoke the actual shell CLI in a temporary committed checkout, with fake I/O.

The HTTP patch is in the test interpreter, never a production base-URL override.
The staging fixture was produced by Terraform 1.15.0 / Cloudflare 5.24.0 with a
synthetic account/token and local state. Computed unknowns are retained verbatim.
"""
import copy
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

FEATURE = Path(__file__).resolve().parents[1]
RELATIVE = Path("infra/terraform/ritual-investing-destination")
ACCOUNT = "1" * 32
SENTINEL = "synthetic-private-widget-secret-never-print"


class CliTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name).resolve()
        self.repo = self.base / "repo"
        self.feature = self.repo / RELATIVE
        shutil.copytree(FEATURE, self.feature, ignore=shutil.ignore_patterns("__pycache__", ".terraform"))
        self.profile = self.feature / "profiles/leoinvestment.json"
        self.profile.write_text(json.dumps({"schema_version": 1, "account_id": ACCOUNT,
                                           "account_name": "LeoInvestment", "settings_verified": True,
                                           "bootstrap_host": socket.gethostname()}))
        self.git("init", "-q")
        self.git("config", "user.name", "CLI test")
        self.git("config", "user.email", "cli-test@example.invalid")
        self.commit()
        self.home = self.base / "home"
        self.home.mkdir()
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.calls = self.base / "calls.jsonl"
        self.http = self.base / "http.json"
        self.http.write_text(json.dumps({"account": {"id": ACCOUNT, "name": "LeoInvestment"},
                                         "buckets": []}))
        # This driver replaces external HTTP only. CLI parsing, Git checks,
        # snapshotting, Terraform invocation, policy, and receipts are real.
        driver = self.base / "http_driver.py"
        driver.write_text('''import io, json, os, runpy, sys, urllib.request
from unittest.mock import patch
from pathlib import Path
class Response(io.BytesIO):
    status = 200
def request(opener, req, *args, **kwargs):
    if os.environ.get("FAKE_RUNTIME"):
        import fake_runtime
        return fake_runtime.request(opener, req, *args, **kwargs)
    data = json.loads(Path(os.environ["FAKE_HTTP"]).read_text())
    with open(os.environ["FAKE_CALLS"], "a") as log:
        log.write(json.dumps({"http": req.full_url, "method": req.method}) + "\\n")
    if not req.full_url.startswith("https://api.cloudflare.com/client/v4/accounts/"):
        raise AssertionError("wrong origin")
    result = {"buckets": data["buckets"]} if "/r2/buckets" in req.full_url else data["account"]
    payload = {"success": True, "errors": [], "result": result, "result_info": {"cursor": None}}
    if data.get("failure"):
        payload = {"success": False, "errors": [{"message": "synthetic-private-widget-secret-never-print"}]}
    return Response(json.dumps(payload).encode())
sys.argv = sys.argv[1:]
sys.path.insert(0, str(Path(sys.argv[0]).parent))
sys.path.insert(0, str(Path(sys.argv[0]).parent / "tests"))
with patch.object(urllib.request.OpenerDirector, "open", request), patch.object(Path, "home", return_value=Path(os.environ["FAKE_PRIVATE_HOME"])):
    runpy.run_path(sys.argv[0], run_name="__main__")
''')
        (self.bin / "python3").write_text(f'#!/bin/sh\nexec "{sys.executable}" -B "{driver}" "$@"\n')
        (self.bin / "python3").chmod(0o755)
        self.terraform = self.bin / "terraform"
        self.terraform.write_text(f'''#!{sys.executable}
import json, os, sys
from pathlib import Path
if os.environ.get("FAKE_RUNTIME"):
    sys.path.insert(0, str(Path(os.environ["FAKE_FEATURE"]) / "tests"))
    import fake_runtime
    raise SystemExit(fake_runtime.terraform())
args = sys.argv[1:]
with open(os.environ["FAKE_CALLS"], "a") as log:
    log.write(json.dumps({{"terraform": args, "cwd": str(Path.cwd())}}) + "\\n")
if args[0] == "version":
    print(json.dumps({{"terraform_version": os.environ.get("FAKE_VERSION", "1.15.0")}}))
elif args[0] == "init":
    print("synthetic-private-widget-secret-never-print")
elif args[0] == "plan":
    for arg in args:
        if arg.startswith("-out="):
            Path(arg[5:]).write_bytes(b"saved-binary-plan-with-synthetic-private-widget-secret-never-print")
    print("synthetic-private-widget-secret-never-print")
    sys.exit(int(os.environ.get("FAKE_PLAN_EXIT", "2")))
elif args[0] == "show":
    p = json.loads(Path(os.environ["FAKE_PLAN"]).read_text())
    print(json.dumps(p))
else:
    sys.exit(99)
''')
        self.terraform.chmod(0o755)
        self.plan = self.base / "plan.json"
        shutil.copyfile(FEATURE / "tests/fixtures/provider-5.24-bootstrap-create.json", self.plan)
        self.env = {"PATH": f"{self.bin}:{os.environ['PATH']}", "FAKE_PRIVATE_HOME": str(self.home),
                    "CLOUDFLARE_API_TOKEN": SENTINEL, "FAKE_HTTP": str(self.http),
                    "FAKE_CALLS": str(self.calls), "FAKE_PLAN": str(self.plan),
                    "RITUAL_TERRAFORM_BIN": str(self.terraform), "PYTHONDONTWRITEBYTECODE": "1"}

    def git(self, *args):
        result = subprocess.run(["git", *args], cwd=self.repo, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def commit(self):
        self.git("add", ".")
        self.git("commit", "-qm", "fixture")

    def invoke(self, *args, human=False):
        command = ["sh", str(self.feature / "provision.sh"), *args]
        if not human:
            command.append("--json")
        result = subprocess.run(command, cwd=self.repo, env=self.env, capture_output=True, text=True)
        self.assertNotIn(SENTINEL, result.stdout + result.stderr)
        if human:
            return result
        self.assertEqual(result.stderr, "")
        receipt = json.loads(result.stdout)
        self.assertEqual(set(receipt), {"schema_version", "action", "profile", "target", "account", "revision",
                                        "plan_identity", "counts", "artifact", "outcome", "recovery"})
        return result.returncode, receipt

    def run_plan(self, target="bootstrap", **kwargs):
        return self.invoke("plan", "--profile", "leoinvestment", "--target", target, **kwargs)

    def recorded_calls(self):
        return [json.loads(line) for line in self.calls.read_text().splitlines()] if self.calls.exists() else []

    def test_plan_changes_manifest_private_snapshot_and_saved_plan(self):
        code, receipt = self.run_plan()
        self.assertEqual(code, 0)
        self.assertEqual(receipt["outcome"], "planned-changes")
        self.assertEqual(receipt["counts"], {"create": 2, "no-op": 0, "update": 0, "delete": 0})
        artifact = Path(receipt["artifact"])
        self.assertTrue(artifact.is_relative_to(self.home / ".local/state/ritual-investing-destination/accounts" / ACCOUNT))
        manifest = json.loads((artifact / "manifest.json").read_text())
        self.assertEqual(manifest["revision"], self.git("rev-parse", "HEAD"))
        self.assertEqual(manifest["backend"]["key"], "bootstrap/terraform.tfstate")
        self.assertEqual(manifest["plan_sha256"], hashlib.sha256((artifact / "plan.tfplan").read_bytes()).hexdigest())
        self.assertIn(str(RELATIVE / "provision.py"), manifest["inputs"])
        self.assertIn(str(RELATIVE / "bootstrap/.terraform.lock.hcl"), manifest["inputs"])
        self.assertNotIn(SENTINEL, (artifact / "receipt.json").read_text())
        for path in artifact.rglob("*"):
            self.assertEqual(path.stat().st_mode & 0o777, 0o700 if path.is_dir() else 0o600)
        commands = [c["terraform"] for c in self.recorded_calls() if "terraform" in c]
        self.assertTrue(any(c[0] == "init" and "-lockfile=readonly" in c for c in commands))
        self.assertFalse(any(c[0] in ("apply", "import", "destroy") or "-lock=false" in c for c in commands))

    def test_apply_rechecks_binary_policy_and_never_applies_unsafe_change(self):
        code, planned = self.run_plan()
        self.assertEqual(code, 0)
        plan = json.loads(self.plan.read_text())
        plan["resource_changes"][0]["change"]["actions"] = ["delete"]
        self.plan.write_text(json.dumps(plan))
        code, receipt = self.invoke("apply", "--profile", "leoinvestment", "--target", "bootstrap", "--artifact", planned["artifact"])
        self.assertEqual((code, receipt["outcome"]), (1, "unsafe-plan"))
        self.assertFalse(any(c.get("terraform", [None])[0] == "apply" for c in self.recorded_calls()))

    def test_apply_consumes_artifact_even_when_terraform_fails(self):
        code, planned = self.run_plan()
        self.assertEqual(code, 0)
        arguments = ("apply", "--profile", "leoinvestment", "--target", "bootstrap", "--artifact", planned["artifact"])
        code, receipt = self.invoke(*arguments)
        self.assertNotEqual(code, 0)
        self.assertTrue((Path(planned["artifact"]) / "consumed.json").is_file())
        self.assertEqual(self.invoke(*arguments)[1]["outcome"], "consumed-plan")
        calls = [c["terraform"] for c in self.recorded_calls() if c.get("terraform", [None])[0] == "apply"]
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0][-1], str(Path(planned["artifact"]) / "plan.tfplan"))

    def test_zero_and_two_success_one_failure_and_human_equivalence(self):
        code, receipt = self.run_plan()
        self.assertEqual((code, receipt["outcome"]), (0, "planned-changes"))
        human = self.run_plan(human=True)
        self.assertEqual(human.returncode, 0)
        self.assertIn(receipt["plan_identity"], human.stdout)
        self.assertIn(receipt["outcome"], human.stdout)
        self.env["FAKE_PLAN_EXIT"] = "1"
        code, failed = self.run_plan()
        self.assertEqual((code, failed["outcome"]), (1, "terraform-failure"))

    def test_argument_protocol_rejects_missing_ambiguous_and_mutating_actions(self):
        cases = [("plan",), ("plan", "--profile", "leoinvestment"),
                 ("plan", "--profile", "leoinvestment", "--target", "prod", "--target", "staging"),
                 ("plan", "--profile", "leoinvestment", "--target", "prod", "--artifact", "unsafe"),
                 ("apply", "--profile", "leoinvestment", "--target", "prod"),
                 ("plan", "--profile", SENTINEL, "--target", "prod")]
        for args in cases:
            with self.subTest(args=args):
                code, receipt = self.invoke(*args)
                self.assertEqual((code, receipt["outcome"]), (1, "invalid-arguments"))
        self.assertEqual(self.recorded_calls(), [])

    def test_unverified_wrong_host_personal_account_or_wrong_name_stops_before_io(self):
        original = json.loads(self.profile.read_text())
        for changes in ({"account_id": None}, {"settings_verified": False}, {"bootstrap_host": "other-host"},
                        {"account_id": "5cc3bc33ca089258d20b6e80e67e5333"}, {"account_name": "personal"}):
            self.profile.write_text(json.dumps({**original, **changes}))
            self.commit()
            code, receipt = self.run_plan()
            self.assertEqual((code, receipt["outcome"]), (1, "prerequisite-failure"))
        self.assertEqual(self.recorded_calls(), [])

    def test_inherited_git_pager_is_harmless_but_selectors_fail(self):
        self.env["GIT_PAGER"] = "cat"
        self.assertEqual(self.run_plan()[0], 0)
        for name in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_CONFIG_COUNT"):
            self.env[name] = "unsafe"
            self.assertEqual(self.run_plan()[1]["outcome"], "unsafe-environment")
            del self.env[name]

    def test_unsafe_environment_variables_cannot_redirect_or_override(self):
        for name in ("TF_VAR_cloudflare_account_id", "TF_CLI_ARGS_plan", "TF_CLI_CONFIG_FILE", "TF_LOG",
                     "TF_LOG_PATH", "TF_DATA_DIR", "TF_WORKSPACE", "TF_REATTACH_PROVIDERS", "TF_INPUT",
                     "AWS_ENDPOINT_URL_S3", "AWS_PROFILE", "AWS_CONFIG_FILE", "AWS_SHARED_CREDENTIALS_FILE",
                     "RITUAL_CLOUDFLARE_API_BASE_URL", "CLOUDFLARE_API_BASE_URL"):
            with self.subTest(name=name):
                self.env[name] = SENTINEL
                code, receipt = self.run_plan()
                self.assertEqual((code, receipt["outcome"]), (1, "unsafe-environment"))
                del self.env[name]
        self.assertEqual(self.recorded_calls(), [])

    def test_relevant_dirty_untracked_ignored_inputs_fail_unrelated_wip_passes(self):
        dirty = self.feature / "bootstrap/main.tf"
        original = dirty.read_bytes()
        dirty.write_bytes(original + b"\n# dirty\n")
        self.assertEqual(self.run_plan()[1]["outcome"], "stale-inputs")
        dirty.write_bytes(original)
        for path in (self.feature / "extra_policy.py", self.feature / "bootstrap/unsafe.auto.tfvars.json",
                     self.feature / "modules/account-resources/override.tf"):
            path.write_text("{}")
            self.assertEqual(self.run_plan()[1]["outcome"], "stale-inputs")
            path.unlink()
        self.git("config", "core.excludesFile", str(self.base / "ignored"))
        (self.base / "ignored").write_text("*.auto.tfvars.json\n")
        extra = self.feature / "bootstrap/ignored.auto.tfvars.json"
        extra.write_text("{}")
        self.assertEqual(self.run_plan()[1]["outcome"], "stale-inputs")
        extra.unlink()
        (self.repo / "unrelated-app.txt").write_text("local WIP")
        self.assertEqual(self.run_plan()[0], 0)

    def test_account_identity_mismatch_api_errors_or_bucket_collision_fail(self):
        for http in ({"account": {"id": "2" * 32, "name": "LeoInvestment"}, "buckets": []},
                     {"account": {"id": ACCOUNT, "name": "Other"}, "buckets": []},
                     {"account": {}, "buckets": [], "failure": True},
                     {"account": {"id": ACCOUNT, "name": "LeoInvestment"},
                      "buckets": [{"name": "ritual-investing-terraform-state-prod"}]}):
            self.http.write_text(json.dumps(http))
            self.assertEqual(self.run_plan()[0], 1)
        self.assertFalse(any("terraform" in c and c["terraform"][0] == "plan" for c in self.recorded_calls()))

    def test_workload_requires_refreshed_bootstrap_gate_and_pinned_version(self):
        self.assertEqual(self.run_plan("staging")[1]["outcome"], "bootstrap-incomplete")
        self.env["FAKE_VERSION"] = "1.5.7"
        self.assertEqual(self.run_plan()[1]["outcome"], "prerequisite-failure")

    def test_saved_artifact_recomputes_current_snapshot_plan_and_binary_integrity(self):
        sys.path.insert(0, str(FEATURE))
        self.addCleanup(sys.path.remove, str(FEATURE))
        from provision import validate_artifact, ProvisionError
        code, receipt = self.run_plan()
        self.assertEqual(code, 0)
        artifact = Path(receipt["artifact"])
        manifest = json.loads((artifact / "manifest.json").read_text())
        profile = json.loads(self.profile.read_text())
        def validate():
            with patch.object(Path, "home", return_value=self.home):
                return validate_artifact(artifact, self.repo, self.feature, profile, "bootstrap", manifest["terraform"])
        self.assertEqual(validate(), manifest)
        for path in (self.feature / "provision.py", self.feature / "plan_policy.py",
                     self.profile, self.feature / "bootstrap/backend.hcl",
                     self.feature / "bootstrap/.terraform.lock.hcl",
                     artifact / "snapshot" / RELATIVE / "bootstrap/main.tf", artifact / "plan.tfplan", self.terraform):
            with self.subTest(path=path.name):
                original = path.read_bytes()
                path.write_bytes(original + b"\nchanged\n")
                with self.assertRaises(ProvisionError):
                    validate()
                path.write_bytes(original)
        extra = artifact / "snapshot" / RELATIVE / "bootstrap/extra.auto.tfvars.json"
        extra.write_text("{}")
        with self.assertRaises(ProvisionError):
            validate()
        extra.unlink()
        self.git("commit", "--allow-empty", "-qm", "new selected revision")
        with self.assertRaises(ProvisionError):
            validate()

    def test_index_change_and_tracked_unsupported_bootstrap_forms_fail(self):
        path = self.feature / "bootstrap/main.tf"
        original = path.read_bytes()
        path.write_bytes(original + b"\n# staged\n")
        self.git("add", str(RELATIVE / "bootstrap/main.tf"))
        path.write_bytes(original)
        self.assertEqual(self.run_plan()[1]["outcome"], "stale-inputs")
        self.git("add", str(RELATIVE / "bootstrap/main.tf"))
        extra = self.feature / "bootstrap/terraform.tfvars.json"
        extra.write_text("{}")
        self.commit()
        self.assertEqual(self.run_plan()[1]["outcome"], "stale-inputs")

    def test_private_directory_inside_checkout_is_rejected(self):
        self.env["FAKE_PRIVATE_HOME"] = str(self.repo)
        self.assertEqual(self.run_plan()[1]["outcome"], "prerequisite-failure")


class ExecutionTests(CliTests):
    # Only the explicit end-to-end tests below are run for this fixture mode.
    def setUp(self):
        super().setUp()
        self.env.update(FAKE_RUNTIME="1", FAKE_FEATURE=str(self.feature), FAKE_REMOTE=str(self.base / "remote"),
                        AWS_ACCESS_KEY_ID="synthetic-access", AWS_SECRET_ACCESS_KEY=SENTINEL)

    def action(self, action, target="bootstrap", artifact=None):
        args = [action, "--profile", "leoinvestment", "--target", target]
        if artifact:
            args += ["--artifact", artifact]
        return self.invoke(*args)

    def provision(self, target="bootstrap"):
        code, plan = self.run_plan(target)
        self.assertEqual((code, plan["outcome"]), (0, "planned-changes"), plan)
        code, applied = self.action("apply", target, plan["artifact"])
        self.assertEqual((code, applied["outcome"]), (0, "applied"), applied)
        return plan, applied

    def test_full_bootstrap_workload_update_verify_chain(self):
        initial, _ = self.provision()
        directory = Path(initial["artifact"]).parent.parent
        phase = json.loads((directory / "phase.json").read_text())
        self.assertEqual(phase["stage"], "RemoteReady")
        self.assertEqual(len(phase["locking_verified"]), 2)
        self.assertEqual(self.run_plan()[1]["outcome"], "planned-no-change")
        workload, applied = self.provision("staging")
        self.assertEqual(applied["counts"]["create"], 15)
        manifest = json.loads((Path(workload["artifact"]) / "manifest.json").read_text())
        self.assertIn(str(RELATIVE / "bootstrap/backend.remote.tf.template"), manifest["inputs"])
        self.assertEqual(manifest["backend"]["key"], "workloads/terraform.tfstate")
        catalog = self.feature / "environments/staging/catalog.json"
        data = json.loads(catalog.read_text())
        data["queues"]["jobs"]["delivery_delay"] = 42
        catalog.write_text(json.dumps(data))
        self.commit()
        code, update = self.run_plan("staging")
        self.assertEqual(code, 0, update)
        self.assertEqual(update["counts"]["update"], 1)
        code, applied = self.action("apply", "staging", update["artifact"])
        self.assertEqual((code, applied["outcome"]), (0, "applied"), applied)
        self.assertEqual(applied["counts"]["update"], 1)
        self.assertEqual(self.action("verify", "staging")[1]["outcome"], "verified")
        self.assertEqual(self.run_plan("staging")[1]["outcome"], "planned-no-change")
        for call in self.recorded_calls():
            if "http" in call:
                self.assertEqual(call["method"], "GET")
            else:
                args = call["terraform"]
                self.assertFalse(any(arg in args for arg in ("import", "destroy", "-lock=false", "force-unlock")))

    def test_post_create_missing_credentials_resume_original_revision(self):
        del self.env["AWS_ACCESS_KEY_ID"]
        del self.env["AWS_SECRET_ACCESS_KEY"]
        code, plan = self.run_plan()
        self.assertEqual(code, 0, plan)
        code, applied = self.action("apply", artifact=plan["artifact"])
        self.assertEqual((code, applied["outcome"]), (1, "bootstrap-incomplete"), applied)
        self.git("commit", "--allow-empty", "-qm", "checkout advanced")
        self.env.update(AWS_ACCESS_KEY_ID="synthetic-access", AWS_SECRET_ACCESS_KEY=SENTINEL)
        code, resumed = self.action("resume")
        self.assertEqual((code, resumed["outcome"]), (0, "resumed"), resumed)
        self.assertEqual(resumed["revision"], plan["revision"])
        self.assertEqual(resumed["plan_identity"], plan["plan_identity"])
        human = self.invoke("resume", "--profile", "leoinvestment", "--target", "bootstrap", human=True)
        self.assertEqual(human.returncode, 0, human.stdout)
        self.assertIn(plan["plan_identity"], human.stdout)
        self.assertIn(plan["revision"], human.stdout)
        self.assertEqual(sum(c.get("terraform", [None])[0] == "apply" for c in self.recorded_calls()), 1)

    def test_partial_initial_apply_replan_and_consumed_artifact(self):
        self.env["FAKE_PARTIAL"] = "1"
        code, plan = self.run_plan()
        self.assertEqual(code, 0, plan)
        code, applied = self.action("apply", artifact=plan["artifact"])
        self.assertEqual((code, applied["outcome"]), (1, "partial-apply"), applied)
        directory = Path(plan["artifact"]).parent.parent
        self.assertFalse((directory / "initialized-bootstrap.json").exists())
        self.assertEqual(self.action("apply", artifact=plan["artifact"])[1]["outcome"], "consumed-plan")
        del self.env["FAKE_PARTIAL"]
        code, replan = self.run_plan()
        self.assertEqual(code, 0, replan)
        self.assertEqual(replan["counts"]["create"], 1)
        self.assertEqual(self.action("apply", artifact=replan["artifact"])[1]["outcome"], "applied")

    def test_unused_bootstrap_snapshot_replans_latest_revision(self):
        code, old = self.run_plan()
        self.assertEqual(code, 0, old)
        self.git("commit", "--allow-empty", "-qm", "new selected revision")
        code, new = self.run_plan()
        self.assertEqual(code, 0, new)
        self.assertNotEqual(old["revision"], new["revision"])
        self.assertEqual(self.action("apply", artifact=old["artifact"])[1]["outcome"], "stale-inputs")
        self.assertEqual(self.action("apply", artifact=new["artifact"])[1]["outcome"], "applied")

    def test_postapply_drift_and_emergency_state_never_succeed(self):
        self.env["FAKE_POST_DRIFT"] = "1"
        code, plan = self.run_plan()
        self.assertEqual(code, 0, plan)
        code, receipt = self.action("apply", artifact=plan["artifact"])
        self.assertEqual((code, receipt["outcome"]), (1, "verification-failure"), receipt)
        directory = Path(plan["artifact"]).parent.parent
        self.assertFalse((directory / "initialized-bootstrap.json").exists())
        self.assertTrue((directory / "authoritative-local.tfstate").is_file())
        self.assertTrue((Path(plan["artifact"]) / "consumed.json").is_file())
        del self.env["FAKE_POST_DRIFT"]
        self.env["FAKE_EMERGENCY"] = "1"
        code, plan = self.run_plan()
        self.assertEqual(code, 0, plan)
        code, receipt = self.action("apply", artifact=plan["artifact"])
        self.assertEqual((code, receipt["outcome"]), (1, "recovery-required"), receipt)
        self.assertTrue((directory / "work/errored.tfstate").is_file())
        self.assertEqual(self.run_plan()[1]["outcome"], "recovery-required")

    def test_remote_runtime_backend_and_state_tamper_require_new_plan(self):
        self.provision()
        code, plan = self.run_plan("staging")
        self.assertEqual(code, 0, plan)
        config = Path(plan["artifact"]) / "work" / RELATIVE / "environments/staging/backend.tfbackend.json"
        original = config.read_bytes()
        config.write_text('{}')
        self.assertEqual(self.action("apply", "staging", plan["artifact"])[1]["outcome"], "stale-inputs")
        config.write_bytes(original)
        self.provision("staging")
        self.assertEqual(self.action("apply", "staging", plan["artifact"])[1]["outcome"], "stale-inputs")

    def test_output_only_bootstrap_reconciliation_uses_saved_plan(self):
        self.provision()
        state = Path(self.env["FAKE_REMOTE"]) / "ritual-investing-terraform-state-prod/bootstrap/terraform.tfstate"
        data = json.loads(state.read_text())
        data["outputs"] = {}
        state.write_text(json.dumps(data))
        code, plan = self.run_plan()
        self.assertEqual((code, plan["outcome"]), (0, "planned-changes"), plan)
        self.assertEqual(plan["counts"], {"create": 0, "update": 0, "delete": 0, "no-op": 2})
        self.assertEqual(self.action("apply", artifact=plan["artifact"])[1]["outcome"], "applied")

    def test_activation_before_apply_stops_without_apply_or_cleanup(self):
        self.provision()
        self.provision("staging")
        code, plan = self.run_plan("staging")
        self.assertEqual(code, 0, plan)
        before = sum(c.get("terraform", [None])[0] == "apply" for c in self.recorded_calls())
        self.env["FAKE_ACTIVATED"] = "1"
        code, receipt = self.action("apply", "staging", plan["artifact"])
        self.assertEqual((code, receipt["outcome"]), (1, "outside-provisioning-scope"), receipt)
        self.assertEqual(sum(c.get("terraform", [None])[0] == "apply" for c in self.recorded_calls()), before)

    def test_unchanged_phase_does_not_mask_public_bucket_or_state_permission(self):
        self.provision()
        self.env["FAKE_PUBLIC"] = "1"
        self.assertEqual(self.run_plan("staging")[1]["outcome"], "outside-provisioning-scope")
        del self.env["FAKE_PUBLIC"]
        self.env["FAKE_S3_DENIED"] = "1"
        self.assertNotEqual(self.run_plan("staging")[0], 0)


# Avoid inheriting the original fake-I/O test cases into the richer fixture.
for _name in dir(CliTests):
    if _name.startswith("test_"):
        setattr(ExecutionTests, _name, None)


class CloudReadTests(unittest.TestCase):
    def setUp(self):
        sys.path.insert(0, str(FEATURE))
        self.addCleanup(sys.path.remove, str(FEATURE))
        from cloud_read import CloudRead, CloudError
        self.error = CloudError
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        with patch.dict(os.environ, {"CLOUDFLARE_API_TOKEN": SENTINEL}):
            self.cloud = CloudRead(ACCOUNT, Path(self.temp.name).resolve())

    def test_complete_bucket_pagination_and_duplicate_or_missing_pages_fail(self):
        pages = [{"result": {"buckets": [{"name": "first"}]}, "result_info": {"cursor": "next"}},
                 {"result": {"buckets": [{"name": "second"}]}, "result_info": {}}]
        with patch.object(self.cloud, "get", side_effect=pages) as get:
            self.assertEqual(self.cloud.buckets(), {"first", "second"})
            self.assertIn("cursor=next", get.call_args.args[0])
        for second in ({"result": {"buckets": []}},
                       {"result": {"buckets": [{"name": "first"}]}, "result_info": {}},
                       {"result": {"buckets": [{"name": "second"}]}, "result_info": {"cursor": "next"}}):
            with patch.object(self.cloud, "get", side_effect=[pages[0], second]):
                with self.assertRaises(self.error):
                    self.cloud.buckets()

    def test_transport_is_fixed_origin_get_only_private_and_never_follows_redirects(self):
        import urllib.error
        class Response(io.BytesIO):
            status = 200
        body = json.dumps({"success": True, "result": {"id": ACCOUNT, "name": "LeoInvestment"}, "secret": SENTINEL}).encode()
        with patch("urllib.request.OpenerDirector.open", return_value=Response(body)) as opened:
            self.assertTrue(self.cloud.verify_account())
            request = opened.call_args.args[0]
            self.assertEqual(request.full_url, f"https://api.cloudflare.com/client/v4/accounts/{ACCOUNT}")
            self.assertEqual(request.method, "GET")
            self.assertNotIn(SENTINEL, request.full_url)
        for path in ("https://attacker.invalid", f"/accounts/{'2' * 32}", f"/accounts/{ACCOUNT}/../unsafe"):
            with self.assertRaises(self.error):
                self.cloud.get(path)
        redirect = urllib.error.HTTPError("https://safe.invalid", 301, SENTINEL,
                                         {"Location": "https://attacker.invalid"}, io.BytesIO(SENTINEL.encode()))
        with patch("urllib.request.OpenerDirector.open", side_effect=redirect) as opened:
            with self.assertRaises(self.error) as raised:
                self.cloud.verify_account()
            self.assertNotIn(SENTINEL, str(raised.exception))
            self.assertEqual(opened.call_count, 1)
        for path in Path(self.temp.name).rglob("*.json"):
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)


class PolicyTests(unittest.TestCase):
    def setUp(self):
        sys.path.insert(0, str(FEATURE))
        self.addCleanup(sys.path.remove, str(FEATURE))
        from plan_policy import inspect_plan, PolicyError
        self.inspect = inspect_plan
        self.error = PolicyError
        self.plan = json.loads((FEATURE / "tests/fixtures/provider-5.24-staging-create.json").read_text())
        self.catalog = json.loads((FEATURE / "environments/staging/catalog.json").read_text())

    def queue_update(self, case):
        fields = json.loads((FEATURE / "tests/fixtures/provider-5.24-queue-update-fields.json").read_text())
        plan, catalog = copy.deepcopy(self.plan), copy.deepcopy(self.catalog)
        queue = next(r for r in plan["resource_changes"] if r["type"] == "cloudflare_queue" and r["index"] == "jobs")
        queue["change"] = fields["cases"][case]
        for side in ("before", "after"):
            queue["change"][side]["queue_name"] = catalog["queues"]["jobs"]["queue_name"]
        catalog["queues"]["jobs"].update(delivery_delay=42,
            message_retention_period=345600 if case == "explicit_retention" else None)
        for resource in plan["planned_values"]["root_module"]["child_modules"][0]["resources"]:
            if resource["address"] == queue["address"]:
                resource["values"] = queue["change"]["after"]
        # Isolate the observed resource contract from independently tested outputs.
        plan["output_changes"] = {}
        plan["planned_values"]["outputs"] = {}
        return plan, catalog, queue["change"]

    def test_real_provider_queue_update_fields_are_accepted_only_after_initialization(self):
        for case in ("explicit_retention", "omitted_retention"):
            with self.subTest(case=case):
                plan, catalog, _ = self.queue_update(case)
                self.assertEqual(self.inspect(plan, ACCOUNT, "staging", catalog, initialized=True)["update"], 1)
                with self.assertRaises(self.error):
                    self.inspect(plan, ACCOUNT, "staging", catalog)

    def test_queue_update_unknown_metadata_does_not_hide_unsafe_values(self):
        mutators = [lambda c: c["after_unknown"]["settings"].update(delivery_paused=True),
                    lambda c: c["after"]["settings"].update(delivery_paused=False),
                    lambda c: c["after_unknown"].update(id=True),
                    lambda c: c["after"].update(queue_id="changed"),
                    lambda c: c["before"].update(consumers=[{"id": "active"}]),
                    lambda c: c["after"].update(consumers=[{"id": "active"}]),
                    lambda c: c["before"]["settings"].update(delivery_paused=False),
                    lambda c: c["after"]["settings"].update(delivery_delay=True)]
        for mutate in mutators:
            plan, catalog, change = self.queue_update("omitted_retention")
            mutate(change)
            with self.assertRaises(self.error):
                self.inspect(plan, ACCOUNT, "staging", catalog, initialized=True)
        plan, catalog, change = self.queue_update("omitted_retention")
        catalog["queues"]["jobs"]["message_retention_period"] = 120
        with self.assertRaises(self.error):
            self.inspect(plan, ACCOUNT, "staging", catalog, initialized=True)
        plan, catalog, change = self.queue_update("explicit_retention")
        catalog["queues"]["jobs"]["message_retention_period"] = 59
        change["after"]["settings"]["message_retention_period"] = 59
        with self.assertRaises(self.error):
            self.inspect(plan, ACCOUNT, "staging", catalog, initialized=True)

    def test_actual_provider_create_unknown_defaults_are_accepted(self):
        self.assertEqual(self.inspect(self.plan, ACCOUNT, "staging", self.catalog),
                         {"create": 15, "no-op": 0, "update": 0, "delete": 0})

    def test_hidden_drift_and_planned_value_resources_fail(self):
        for field in ("resource_drift", "planned_values"):
            plan = copy.deepcopy(self.plan)
            if field == "resource_drift":
                plan[field] = [copy.deepcopy(plan["resource_changes"][0])]
                plan[field][0]["change"]["actions"] = ["delete"]
            else:
                plan[field]["root_module"]["resources"] = [{"address": "hidden.resource"}]
            with self.assertRaises(self.error):
                self.inspect(plan, ACCOUNT, "staging", self.catalog)

    def test_explicit_queue_values_reject_bool_fraction_and_bounds(self):
        for value in (True, -1, 86401, 1.5):
            plan, catalog = copy.deepcopy(self.plan), copy.deepcopy(self.catalog)
            queue = next(r for r in plan["resource_changes"] if r["type"] == "cloudflare_queue")
            key = queue["index"]
            catalog["queues"][key]["delivery_delay"] = value
            queue["change"]["after"]["settings"]["delivery_delay"] = value
            queue["change"]["after_unknown"]["settings"].pop("delivery_delay", None)
            with self.assertRaises(self.error):
                self.inspect(plan, ACCOUNT, "staging", catalog)

    def test_policy_rejects_scope_actions_wrong_account_unknown_activation_and_integration(self):
        mutators = [lambda p: p["resource_changes"][0]["change"].update(actions=["delete", "create"]),
                    lambda p: p["resource_changes"][0]["change"].update(actions=["update"]),
                    lambda p: p["resource_changes"][0].update(address="outside.address"),
                    lambda p: p["resource_changes"][0]["change"]["after"].update(account_id="2" * 32),
                    lambda p: p["resource_changes"].pop(),
                    lambda p: p["resource_changes"][0]["change"]["after"].update(source={"type": "github"}),
                    lambda p: p["resource_changes"][0]["change"]["after_unknown"].update(account_id=True),
                    lambda p: p["configuration"]["root_module"]["module_calls"]["account_resources"]["module"]["resources"][0]["expressions"].update(deployment_configs={}),
                    lambda p: p.update(complete=False)]
        for mutate in mutators:
            plan = copy.deepcopy(self.plan)
            mutate(plan)
            with self.assertRaises(self.error):
                self.inspect(plan, ACCOUNT, "staging", self.catalog)
        for kind, field, value in (("cloudflare_worker", "subdomain", {"enabled": True, "previews_enabled": False}),
                                   ("cloudflare_queue", "settings", {"delivery_paused": False}),
                                   ("cloudflare_turnstile_widget", "clearance_level", "managed")):
            plan = copy.deepcopy(self.plan)
            r = next(r for r in plan["resource_changes"] if r["type"] == kind)
            r["change"]["after"][field] = value
            with self.assertRaises(self.error):
                self.inspect(plan, ACCOUNT, "staging", self.catalog)


if __name__ == "__main__":
    unittest.main()
