"""Compare declared expectations with an independently implemented sample consumer."""

import json
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
RULES = ROOT / "cmd/main/testdata/consumer.json"
CASES = [
    ("default_parent", {"server": {"port": 8080}}, True, "info"),
    ("default_leaf", {"server": {"port": 9090}, "logging": {}}, True, "info"),
    ("explicit_value", {"server": {"port": 8080}, "logging": {"level": "warn"}}, True, "warn"),
    ("missing_required", {"server": {}}, False, None),
    ("disallowed_value", {"server": {"port": 9999}}, False, None),
    ("wrong_type", {"server": {"port": "8080"}}, False, None),
    ("explicit_null", {"server": {"port": 8080}, "logging": {"level": None}}, False, None),
    ("blocked_parent", {"server": {"port": 8080}, "logging": 42}, False, None),
    ("missing_server", {}, False, None),
    ("invalid_root", [], False, None),
]


def run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, cwd=ROOT, capture_output=True, text=True, encoding="utf-8")


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="configscope-behavior-") as directory:
        for name, configuration, expected, level in CASES:
            path = Path(directory) / f"{name}.json"
            path.write_text(json.dumps(configuration), encoding="utf-8")
            consumer = run("moon", "run", "examples/service_consumer", "--", str(path))
            checker = run("moon", "run", "cmd/main", "--", "consumer-check", str(path), str(RULES), "--format", "json")
            expected_code = 0 if expected else 1
            if consumer.returncode != expected_code or checker.returncode != expected_code:
                raise SystemExit(f"{name}: expected status {expected_code}\nconsumer: {consumer.stdout}{consumer.stderr}\nchecker: {checker.stdout}{checker.stderr}")
            report = json.loads(checker.stdout)
            if report["passed"] != expected:
                raise SystemExit(f"{name}: report disagrees with consumer result")
            if expected and f"log={level}" not in consumer.stdout:
                raise SystemExit(f"{name}: consumer did not apply the expected logging value")
            print(f"{name}: consumer={'accepted' if expected else 'rejected'}, checker agrees")
    print(f"Consumer behavior: {len(CASES)}/{len(CASES)} cases agreed.")


if __name__ == "__main__":
    main()
