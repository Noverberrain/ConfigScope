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
    ("workers_minimum", {"server": {"port": 8080, "workers": 1}}, True, "info"),
    ("workers_maximum", {"server": {"port": 8080, "workers": 64}}, True, "info"),
    ("workers_regular", {"server": {"port": 8080, "workers": 24}}, True, "info"),
    ("workers_below", {"server": {"port": 8080, "workers": 0}}, False, None),
    ("workers_above", {"server": {"port": 8080, "workers": 65}}, False, None),
    ("workers_fraction", {"server": {"port": 8080, "workers": 4.5}}, False, None),
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
            if expected:
                settings = dict(token.split("=", 1) for token in consumer.stdout.split() if "=" in token)
                if settings.get("log") != level:
                    raise SystemExit(f"{name}: consumer did not apply the expected logging value")
                workers = configuration["server"].get("workers", 4)
                if settings.get("workers") != f"{workers:g}":
                    raise SystemExit(f"{name}: consumer did not apply the expected worker count")
            print(f"{name}: consumer={'accepted' if expected else 'rejected'}, checker agrees")
    print(f"Consumer behavior: {len(CASES)}/{len(CASES)} cases agreed.")


if __name__ == "__main__":
    main()
