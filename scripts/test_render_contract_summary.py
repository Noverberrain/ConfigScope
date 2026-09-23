"""Regression tests for the GitHub Actions contract summary."""

import unittest

from render_contract_summary import render_summary


def report(*, passed: bool, breaking: bool = False) -> dict:
    changes = (
        [{"path": "server.port", "kind": "type_changed", "impact": "breaking"}]
        if breaking
        else []
    )
    return {
        "kind": "compatibility_contract",
        "contract": "release.contract.json",
        "candidate": "candidate.json",
        "gate": "breaking",
        "passed": passed,
        "ignored_change_count": 2,
        "summary": {"passed": int(passed), "failed": int(not passed), "total": 1},
        "baselines": [
            {
                "baseline": "v1.json",
                "passed": passed,
                "summary": {
                    "breaking": int(breaking),
                    "behavioral": 0,
                    "compatible": 0,
                    "violations": int(breaking),
                },
                "changes": changes,
            }
        ],
    }


class ContractSummaryTests(unittest.TestCase):
    def test_passed_contract(self) -> None:
        output = render_summary(report(passed=True))
        self.assertIn("**Result: PASSED**", output)
        self.assertIn("| v1.json | passed | 0 | 0 | 0 | 0 |", output)
        self.assertIn("- Ignored changes: 2", output)
        self.assertIn("### Gate violations\n\nNone.", output)

    def test_failed_contract_shows_breaking_path_without_values(self) -> None:
        output = render_summary(report(passed=False, breaking=True))
        self.assertIn("**Result: FAILED**", output)
        self.assertIn("| v1.json | failed | 1 | 0 | 0 | 1 |", output)
        self.assertIn("- v1.json: [breaking] type&#95;changed at server.port", output)
        self.assertNotIn("before", output)
        self.assertNotIn("after", output)

    def test_manifest_names_cannot_inject_markdown(self) -> None:
        data = report(passed=True)
        data["baselines"][0]["baseline"] = "v1|bad\n## [surprise](url).md"
        output = render_summary(data)
        self.assertIn("v1&#124;bad&#10;&#35;&#35; &#91;surprise&#93;&#40;url&#41;.md", output)
        self.assertNotIn("\n## surprise", output)

    def test_behavioral_gate_lists_behavioral_violations(self) -> None:
        data = report(passed=False)
        data["gate"] = "behavioral"
        data["baselines"][0]["changes"] = [
            {"path": "server.port", "kind": "changed", "impact": "behavioral"}
        ]
        output = render_summary(data)
        self.assertIn("- v1.json: [behavioral] changed at server.port", output)

    def test_any_gate_lists_added_paths_as_violations(self) -> None:
        data = report(passed=False)
        data["gate"] = "any"
        data["baselines"][0]["changes"] = [
            {"path": "logging", "kind": "added", "impact": "compatible"}
        ]
        output = render_summary(data)
        self.assertIn("- v1.json: [compatible] added at logging", output)

    def test_rejects_other_report_kinds(self) -> None:
        data = report(passed=True)
        data["kind"] = "compatibility_matrix"
        with self.assertRaises(ValueError):
            render_summary(data)


if __name__ == "__main__":
    unittest.main()
