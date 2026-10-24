"""Regression checks for the CI release-policy verifier, without invoking moon."""

import copy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from check_release_cases import CASES, ROOT, render_summary, run_cases, verify


def good(case):
    manifest = json.loads((ROOT / case.manifest).read_text(encoding="utf-8"))
    entries = []
    for spec in sorted(manifest["bindings"], key=lambda s: (s["consumer"], s["version"])):
        entry = {k: spec[k] for k in ("consumer", "version", "baseline_id", "contract", "baseline")}
        invalid_candidate = case.name == "rejected" and spec["version"] == "v2"
        invalid_history = case.name == "preserve-unknown"
        issue = {"path": "timeout", "kind": "above_maximum"}
        comparable = not invalid_candidate and not invalid_history
        blockers = [{"reason": reason, "path": path}
                    for version, reason, path in case.blockers if version == spec["version"]]
        changes = [] if not comparable else [{
            "path": "timeout", "before": "explicit", "after": "default",
            "value_changed": spec["version"] == "v2",
        }]
        entry.update(candidate_accepted=not invalid_candidate, release_allowed=not blockers,
                     introduced=[issue] if invalid_candidate else [], persistent=[],
                     resolved=[issue] if invalid_history else [],
                     effective_comparable=comparable,
                     effective_values_preserved=(not any(c["value_changed"] for c in changes)) if comparable else None,
                     effective_changes=changes, blockers=blockers)
        entries.append(entry)
    allowed = sum(e["release_allowed"] for e in entries)
    return {"kind": "consumer_release_report", "schema_version": 1,
            "scope": "declared_consumer_versions", "manifest": case.manifest,
            "candidate": manifest["candidate"], "policy": case.policy,
            "candidate_accepted": case.accepted, "passed": case.allowed,
            "decision": "allowed" if case.allowed else "blocked",
            "summary": {"allowed": allowed, "blocked": len(entries) - allowed, "total": len(entries)},
            "consumers": entries}


def completed(case):
    return subprocess.CompletedProcess([], case.exit_code, json.dumps(good(case)), "")


class ReleaseCaseTests(unittest.TestCase):
    def test_expected_allowed_and_blocked_cases_are_successful_verifications(self):
        for case in CASES:
            with self.subTest(case=case.name):
                self.assertEqual(verify(case, case.exit_code, json.dumps(good(case))), good(case))

    def test_crash_wrong_exit_and_text_errors_cannot_pass_as_expected_denials(self):
        case = CASES[1]
        for code, output in [(2, json.dumps(good(case))), (0, json.dumps(good(case))),
                             (1, "error: file missing"), (1, "{}")]:
            with self.subTest(code=code, output=output):
                with self.assertRaises((ValueError, KeyError)):
                    verify(case, code, output)

    def test_wrong_schema_policy_counts_bindings_and_blockers_are_rejected(self):
        case = CASES[1]
        mutations = [
            lambda r: r.update(schema_version=True),
            lambda r: r.update(kind="consumer_report"),
            lambda r: r.update(policy="accept"),
            lambda r: r.update(passed=True),
            lambda r: r["summary"].update(total=99),
            lambda r: r["consumers"][0].update(baseline_id="wrong"),
            lambda r: r["consumers"][1]["blockers"][0].update(reason="wrong_reason"),
            lambda r: r["consumers"].reverse(),
        ]
        for mutate in mutations:
            data = copy.deepcopy(good(case))
            mutate(data)
            with self.assertRaises(ValueError):
                verify(case, case.exit_code, json.dumps(data))

    def test_unknown_must_remain_null_and_known_preservation_must_match_changes(self):
        unknown = good(CASES[3])
        unknown["consumers"][0]["effective_values_preserved"] = True
        with self.assertRaises(ValueError):
            verify(CASES[3], 1, json.dumps(unknown))
        changed = good(CASES[1])
        changed["consumers"][1]["effective_values_preserved"] = True
        with self.assertRaises(ValueError):
            verify(CASES[1], 1, json.dumps(changed))

    def test_value_leak_and_unexpected_change_fields_are_rejected(self):
        case = CASES[0]
        data = good(case)
        data["consumers"][0]["effective_changes"][0]["value"] = 30
        with self.assertRaises(ValueError):
            verify(case, 0, json.dumps(data))
        with self.assertRaises(ValueError):
            verify(case, 0, json.dumps(good(case)) + "SENSITIVE_RELEASE_FIXTURE")

    def test_runner_retains_reports_and_expected_denials_do_not_fail_suite(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / "evidence"
            with patch("check_release_cases.subprocess.run", side_effect=[completed(c) for c in CASES]), patch("builtins.print"):
                results = run_cases(output)
            self.assertTrue(all(r["verified"] for r in results))
            self.assertEqual(len(list(output.glob("*.json"))), 6)
            self.assertTrue(json.loads((output / "results.json").read_text())["verified"])
            with self.assertRaises(FileExistsError):
                run_cases(output)

    def test_runner_continues_and_saves_index_after_timeout_or_text_error(self):
        outcomes = [subprocess.TimeoutExpired("moon", 120),
                    subprocess.CompletedProcess([], 1, "error: missing file", "")]
        outcomes += [completed(c) for c in CASES[2:]]
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / "evidence"
            with patch("check_release_cases.subprocess.run", side_effect=outcomes), patch("builtins.print"):
                results = run_cases(output)
            self.assertEqual([r["verified"] for r in results], [False, False, True, True, True])
            self.assertFalse(json.loads((output / "results.json").read_text())["verified"])
            self.assertEqual((output / "preserve.json").read_text(), "error: missing file")

    def test_summary_marks_expected_denials_as_tests_and_escapes_labels(self):
        results = [{"case": "case|bad\n# forged", "expected_exit": 1, "actual_exit": 1,
                    "verified": True, "blockers": ["svc<script>@v2: changed"]}]
        summary = render_summary(results)
        self.assertIn("Verified **1/1**", summary)
        self.assertIn("Expected denials count as successful tests", summary)
        self.assertNotIn("<script>", summary)
        self.assertNotIn("\n# forged", summary)
        self.assertIn("&#124;", summary)


if __name__ == "__main__":
    unittest.main()
