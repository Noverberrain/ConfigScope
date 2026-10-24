"""Verify fixed release-policy cases and retain JSON evidence for CI."""

import argparse
from dataclasses import dataclass
import json
from pathlib import Path
import subprocess

from render_contract_summary import markdown_text

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = "cmd/main/testdata/release/"


@dataclass(frozen=True)
class Case:
    name: str
    policy: str
    accepted: bool
    allowed: bool
    versions: tuple[str, ...]
    blockers: tuple[tuple[str, str, str | None], ...] = ()

    @property
    def manifest(self) -> str:
        return FIXTURES + self.name + ".release.json"

    @property
    def exit_code(self) -> int:
        return 0 if self.allowed else 1


CASES = (
    Case("defaults", "accept", True, True, ("v1", "v2")),
    Case("preserve", "preserve-effective", True, False, ("v1", "v2"),
         (("v2", "effective_value_changed", "timeout"),)),
    Case("preserve-equal", "preserve-effective", True, True, ("v1",)),
    Case("preserve-unknown", "preserve-effective", True, False, ("v2",),
         (("v2", "effective_incomparable", None),)),
    Case("rejected", "accept", False, False, ("v1", "v2"),
         (("v2", "candidate_above_maximum", "timeout"),)),
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def verify(case: Case, exit_code: int, stdout: str) -> dict:
    """A crash, text error or wrong blocker must not count as expected denial."""
    require(exit_code == case.exit_code, "unexpected process exit code")
    require("SENSITIVE_RELEASE_FIXTURE" not in stdout, "fixture value leaked")
    report = json.loads(stdout)
    require(report["kind"] == "consumer_release_report", "wrong report kind")
    require(type(report["schema_version"]) is int and report["schema_version"] == 1,
            "unsupported report schema")
    require(report["scope"] == "declared_consumer_versions", "wrong report scope")
    require(report["manifest"] == case.manifest, "wrong manifest reference")
    require(report["policy"] == case.policy, "wrong policy")
    require(report["candidate_accepted"] is case.accepted, "wrong candidate acceptance")
    require(report["passed"] is case.allowed, "wrong release outcome")
    require(report["decision"] == ("allowed" if case.allowed else "blocked"),
            "inconsistent decision")
    entries = report["consumers"]
    require(tuple(e["version"] for e in entries) == case.versions,
            "wrong consumer versions or order")
    manifest = json.loads((ROOT / case.manifest).read_text(encoding="utf-8"))
    require(report["candidate"] == manifest["candidate"], "wrong candidate reference")
    specs = {(s["consumer"], s["version"]): s for s in manifest["bindings"]}
    blockers = []
    for entry in entries:
        spec = specs[(entry["consumer"], entry["version"])]
        require(all(entry[k] == spec[k] for k in ("baseline_id", "contract", "baseline")),
                "binding references changed")
        require(type(entry["candidate_accepted"]) is bool, "invalid acceptance flag")
        require(type(entry["release_allowed"]) is bool, "invalid release flag")
        require(type(entry["effective_comparable"]) is bool, "invalid comparison flag")
        comparable = entry["effective_comparable"]
        if comparable:
            require(type(entry["effective_values_preserved"]) is bool,
                    "comparable selection must have a boolean result")
        else:
            require(entry["effective_values_preserved"] is None and
                    entry["effective_changes"] == [], "unknown must not mean unchanged")
        for category in ("introduced", "persistent", "resolved"):
            require(type(entry[category]) is list, "invalid issue array")
            for issue in entry[category]:
                require(set(issue) == {"path", "kind"}, "unexpected issue fields")
        require(entry["candidate_accepted"] is (not entry["introduced"] and not entry["persistent"]),
                "candidate flag disagrees with violations")
        require(comparable is (not entry["introduced"] and not entry["persistent"] and not entry["resolved"]),
                "comparison flag disagrees with snapshot validity")
        for change in entry["effective_changes"]:
            require(set(change) == {"path", "before", "after", "value_changed"},
                    "unexpected effective-change fields")
            require(type(change["value_changed"]) is bool, "invalid change flag")
            require(change["before"] in ("inactive", "missing", "explicit", "default") and
                    change["after"] in ("inactive", "missing", "explicit", "default"),
                    "invalid effective source")
        if comparable:
            require(entry["effective_values_preserved"] is
                    (not any(c["value_changed"] for c in entry["effective_changes"])),
                    "preservation flag disagrees with changes")
        for blocker in entry["blockers"]:
            require(set(blocker) == {"reason", "path"}, "unexpected blocker fields")
            blockers.append((entry["version"], blocker["reason"], blocker["path"]))
        require(entry["release_allowed"] is (len(entry["blockers"]) == 0),
                "entry decision disagrees with blockers")
    require(tuple(blockers) == case.blockers, "unexpected blocker attribution")
    require(all(e["candidate_accepted"] for e in entries) is case.accepted,
            "candidate aggregate mismatch")
    allowed = sum(e["release_allowed"] for e in entries)
    summary = report["summary"]
    require(all(type(summary[k]) is int for k in ("allowed", "blocked", "total")),
            "invalid summary counts")
    require(summary == {"allowed": allowed, "blocked": len(entries) - allowed,
                        "total": len(entries)}, "summary mismatch")
    require((allowed == len(entries)) is case.allowed, "release aggregate mismatch")
    return report


def run_cases(output_dir: Path) -> list[dict]:
    # Refuse a reused directory: stale evidence must not mask a failed run.
    output_dir.mkdir(parents=True, exist_ok=False)
    results = []
    for case in CASES:
        result = {"case": case.name, "manifest": case.manifest,
                  "expected_exit": case.exit_code, "actual_exit": None,
                  "verified": False, "report": case.name + ".json", "blockers": []}
        try:
            completed = subprocess.run(
                ["moon", "run", "cmd/main", "--", "release-check", case.manifest,
                 "--format", "json"], cwd=ROOT, capture_output=True, text=True,
                encoding="utf-8", timeout=120,
            )
            result["actual_exit"] = completed.returncode
            (output_dir / result["report"]).write_text(completed.stdout, encoding="utf-8")
            report = verify(case, completed.returncode, completed.stdout)
            result["verified"] = True
            result["blockers"] = [
                f"{e['consumer']}@{e['version']}: {b['reason']} ({b['path'] or 'no path'})"
                for e in report["consumers"] for b in e["blockers"]
            ]
        except (ValueError, KeyError, TypeError, OSError, subprocess.TimeoutExpired) as error:
            result["error"] = type(error).__name__ + ": release case verification failed"
        results.append(result)
        print(f"{case.name}: expected exit={case.exit_code}, "
              f"actual={result['actual_exit']}, verified={result['verified']}")
    (output_dir / "results.json").write_text(
        json.dumps({"verified": all(r["verified"] for r in results), "cases": results},
                   indent=2) + "\n", encoding="utf-8",
    )
    return results


def render_summary(results: list[dict]) -> str:
    count = sum(r["verified"] for r in results)
    lines = ["## ConfigScope release-policy cases", "",
             f"Verified **{count}/{len(results)}** cases. Expected denials count as successful tests.",
             "", "| Case | Expected exit | Actual exit | Verified |",
             "| --- | ---: | ---: | --- |"]
    for result in results:
        lines.append(f"| {markdown_text(result['case'])} | {result['expected_exit']} | "
                     f"{result['actual_exit']} | {result['verified']} |")
    lines.extend(["", "### Verified blocker evidence", ""])
    for result in results:
        if result["verified"]:
            for blocker in result["blockers"]:
                lines.append("- " + markdown_text(result["case"] + ": " + blocker))
    lines.append("\nFixed fixture coverage only; this is not a guarantee about arbitrary consumers.")
    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output_dir", type=Path, help="new directory for fixture reports")
    parser.add_argument("--summary", type=Path, help="append Markdown to this file")
    args = parser.parse_args()
    results = run_cases(args.output_dir)
    if args.summary:
        with args.summary.open("a", encoding="utf-8") as stream:
            stream.write(render_summary(results))
    if not all(result["verified"] for result in results):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
