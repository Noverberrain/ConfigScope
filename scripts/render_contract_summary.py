"""Render a value-free GitHub Actions summary from contract-check JSON."""

import html
import json
from pathlib import Path
import sys


def markdown_text(value: str) -> str:
    """Keep manifest-supplied names from altering the Markdown layout."""
    special = "|`\r\n\\[]()*_!#"
    return "".join(
        f"&#{ord(character)};" if character in special else html.escape(character)
        for character in value
    )


def render_summary(report: dict) -> str:
    if report["kind"] != "compatibility_contract":
        raise ValueError("Expected a compatibility_contract report")

    result = "PASSED" if report["passed"] else "FAILED"
    counts = report["summary"]
    lines = [
        "## ConfigScope compatibility contract",
        "",
        f"**Result: {result}** | Gate: `{markdown_text(report['gate'])}`",
        "",
        f"- Contract: `{markdown_text(report['contract'])}`",
        f"- Candidate: `{markdown_text(report['candidate'])}`",
        f"- Baselines: {counts['passed']} passed, {counts['failed']} failed, {counts['total']} total",
        f"- Ignored changes: {report['ignored_change_count']}",
        "",
        "| Baseline | Result | Breaking | Behavioral | Compatible | Gate violations |",
        "| --- | --- | ---: | ---: | ---: | ---: |",
    ]
    for entry in report["baselines"]:
        summary = entry["summary"]
        status = "passed" if entry["passed"] else "failed"
        lines.append(
            f"| {markdown_text(entry['baseline'])} | {status} | "
            f"{summary['breaking']} | {summary['behavioral']} | "
            f"{summary['compatible']} | {summary['violations']} |"
        )

    violating_impacts = {
        "breaking": {"breaking"},
        "behavioral": {"breaking", "behavioral"},
        "any": {"breaking", "behavioral", "compatible"},
    }[report["gate"]]
    violations = [
        (entry["baseline"], change)
        for entry in report["baselines"]
        for change in entry["changes"]
        if change["impact"] in violating_impacts
    ]
    lines.extend(["", "### Gate violations", ""])
    if violations:
        for baseline, change in violations:
            lines.append(
                f"- {markdown_text(baseline)}: "
                f"[{markdown_text(change['impact'])}] "
                f"{markdown_text(change['kind'])} at "
                f"{markdown_text(change['path'] or '<root>')}"
            )
    else:
        lines.append("None.")
    return "\n".join(lines) + "\n"


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: render_contract_summary.py REPORT_JSON_PATH")
    report = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    sys.stdout.write(render_summary(report))


if __name__ == "__main__":
    main()
