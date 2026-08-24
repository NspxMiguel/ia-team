import json
import os
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
TEAM_MODELS = ROOT / "bin" / "team-models"


class TeamModelsTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.home = self.root / "home"
        (self.home / "agents").mkdir(parents=True)
        self.endpoint = self.root / "provider" / "v1"
        self.endpoint.mkdir(parents=True)
        self.set_payload({"data": []})

    def tearDown(self):
        self.temporary.cleanup()

    def set_payload(self, payload):
        (self.endpoint / "models").write_text(json.dumps(payload), encoding="utf-8")

    def adapter(
        self,
        name="fake",
        key_env="MODELS_TEST_KEY",
        default="qwen2.5-coder",
        ask="qwen2.5-coder-fast",
        optional=False,
    ):
        contents = "\n".join(
            [
                'ADAPTER_ID="%s"' % name,
                'CLOUD_BASE_URL="%s"' % self.endpoint.as_uri(),
                'CLOUD_KEY_ENV="%s"' % key_env,
                'CLOUD_MODEL="%s"' % default,
                'CLOUD_ASK_MODEL="%s"' % ask,
                "CLOUD_KEY_OPTIONAL=1" if optional else "CLOUD_KEY_OPTIONAL=0",
                "",
            ]
        )
        (self.home / "agents" / (name + ".sh")).write_text(
            contents, encoding="utf-8"
        )

    def run_models(self, *arguments, env=None):
        process_env = os.environ.copy()
        process_env["IA_TEAM_HOME"] = str(self.home)
        if env:
            process_env.update(env)
        return subprocess.run(
            [sys.executable, str(TEAM_MODELS)] + list(arguments),
            env=process_env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=10,
            check=False,
        )

    def state(self):
        with (self.home / "state" / "models.json").open(encoding="utf-8") as handle:
            return json.load(handle)

    def test_reads_adapter_queries_with_environment_key_and_records_state(self):
        self.adapter()
        self.set_payload(
            {
                "data": [
                    {
                        "id": "qwen2.5-coder",
                        "pricing": {"prompt": "0", "completion": 0},
                    },
                    {"id": "qwen2.5-coder-fast", "is_free": True},
                    {"id": "llama-3.3", "pricing": {"prompt": "0.2"}},
                ]
            }
        )

        result = self.run_models("--once", env={"MODELS_TEST_KEY": "secret"})

        self.assertEqual(result.returncode, 0, result.stderr)
        record = self.state()["adapters"]["fake"]
        self.assertEqual(
            record["ids"], ["llama-3.3", "qwen2.5-coder", "qwen2.5-coder-fast"]
        )
        self.assertEqual(record["free_ids"], ["qwen2.5-coder", "qwen2.5-coder-fast"])
        self.assertTrue(record["default_exists"])
        self.assertTrue(record["default_free"])
        self.assertTrue(record["ask_model_exists"])
        self.assertEqual(record["status"], "ok")
        self.assertIsNotNone(record["checked_at"])
        self.assertEqual(record["history"], [])

    def test_tracks_changes_and_suggests_a_free_model_from_the_same_family(self):
        self.adapter(ask="")
        environment = {"MODELS_TEST_KEY": "secret"}
        self.set_payload(
            {
                "data": [
                    {"id": "qwen2.5-coder", "free": True},
                    {"id": "qwen3-coder", "free": True},
                    {"id": "llama-3.3", "free": True},
                ]
            }
        )
        self.assertEqual(self.run_models("--once", env=environment).returncode, 0)

        self.set_payload(
            {
                "data": [
                    {"id": "qwen3-coder", "free": True},
                    {"id": "llama-3.3", "free": True},
                ]
            }
        )
        self.assertEqual(self.run_models("--once", env=environment).returncode, 0)
        record = self.state()["adapters"]["fake"]
        self.assertFalse(record["default_exists"])
        self.assertEqual(record["suggestion"], "qwen3-coder")
        self.assertIn("qwen2.5-coder", record["history"][-1]["removed"])

        self.set_payload(
            {
                "data": [
                    {"id": "qwen2.5-coder", "free": False},
                    {"id": "qwen3-coder", "free": True},
                ]
            }
        )
        self.assertEqual(self.run_models("--once", env=environment).returncode, 0)
        record = self.state()["adapters"]["fake"]
        self.assertTrue(record["default_exists"])
        self.assertFalse(record["default_free"])
        self.assertEqual(record["suggestion"], "qwen3-coder")

        self.set_payload(
            {
                "data": [
                    {"id": "qwen2.5-coder", "free": True},
                    {"id": "qwen3-coder", "free": True},
                ]
            }
        )
        self.assertEqual(self.run_models("--once", env=environment).returncode, 0)
        record = self.state()["adapters"]["fake"]
        self.assertTrue(record["default_free"])
        self.assertIsNone(record["suggestion"])
        self.assertIn("qwen2.5-coder", record["history"][-1]["became_free"])
        history_size = len(record["history"])
        self.assertEqual(self.run_models("--once", env=environment).returncode, 0)
        self.assertEqual(
            len(self.state()["adapters"]["fake"]["history"]), history_size
        )

    def test_default_run_obeys_recorded_interval_and_quiet(self):
        self.adapter(optional=True)
        self.set_payload({"data": [{"id": "qwen2.5-coder"}]})
        first = self.run_models("--once", "--interval-dias", "3", "--quiet")
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual(first.stdout, "")
        self.assertEqual(first.stderr, "")

        self.set_payload(
            {"data": [{"id": "qwen2.5-coder"}, {"id": "would-show-a-query"}]}
        )
        second = self.run_models("--quiet")
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(self.state()["adapters"]["fake"]["ids"], ["qwen2.5-coder"])
        self.assertEqual(self.state()["interval_days"], 3)

    def test_uses_claude_autonomous_when_key_is_not_in_environment(self):
        self.adapter(key_env="KEYCHAIN_MODELS_KEY")
        self.set_payload({"data": [{"id": "qwen2.5-coder", "free": True}]})
        fake_bin = self.root / "bin"
        fake_bin.mkdir()
        marker = self.root / "keychain-was-used"
        wrapper = fake_bin / "claude-autonomous"
        wrapper.write_text(
            "#!/bin/sh\n"
            "[ \"$1\" = run ] || exit 2\n"
            "name=$2\n"
            "shift 3\n"
            "export \"$name=from-keychain\"\n"
            'touch "%s"\n' % marker
            + "exec \"$@\"\n",
            encoding="utf-8",
        )
        wrapper.chmod(wrapper.stat().st_mode | stat.S_IXUSR)
        environment = {"PATH": str(fake_bin) + os.pathsep + os.environ.get("PATH", "")}

        result = self.run_models("--once", env=environment)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.state()["adapters"]["fake"]["status"], "ok")
        self.assertTrue(marker.exists())

    def test_unmarked_free_status_is_null_and_previous_snapshot_survives_errors(self):
        self.adapter(optional=True)
        self.set_payload({"data": [{"id": "qwen2.5-coder"}]})
        self.assertEqual(self.run_models("--once").returncode, 0)
        original = self.state()["adapters"]["fake"]
        self.assertFalse(original["free_marked"])
        self.assertIsNone(original["default_free"])

        (self.endpoint / "models").unlink()
        result = self.run_models("--once", "--quiet")

        self.assertEqual(result.returncode, 0)
        record = self.state()["adapters"]["fake"]
        self.assertEqual(record["status"], "unavailable")
        self.assertEqual(record["ids"], ["qwen2.5-coder"])
        self.assertEqual(record["checked_at"], original["checked_at"])
        self.assertEqual(list((self.home / "state").glob(".models.*.tmp")), [])

    def test_concurrent_runs_leave_one_complete_atomic_state(self):
        self.adapter(optional=True)
        self.set_payload(
            {"data": [{"id": "qwen2.5-coder"}, {"id": "qwen3-coder"}]}
        )
        environment = os.environ.copy()
        environment["IA_TEAM_HOME"] = str(self.home)
        command = [sys.executable, str(TEAM_MODELS), "--once", "--quiet"]

        first = subprocess.Popen(command, env=environment)
        second = subprocess.Popen(command, env=environment)
        self.assertEqual(first.wait(timeout=10), 0)
        self.assertEqual(second.wait(timeout=10), 0)

        state = self.state()
        self.assertEqual(
            state["adapters"]["fake"]["ids"], ["qwen2.5-coder", "qwen3-coder"]
        )
        self.assertEqual(list((self.home / "state").glob(".models.*.tmp")), [])


if __name__ == "__main__":
    unittest.main()
