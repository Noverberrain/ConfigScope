"""Run the README example in a fresh project using the published package."""

from pathlib import Path
import re
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
SECTION = "### Use from another MoonBit project\n"
EXPECTED_OUTPUT = "breaking changes: 1"


def example_from(readme: Path) -> tuple[str, str, str]:
    content = readme.read_text(encoding="utf-8").replace("\r\n", "\n")
    section = content.split(SECTION, 1)[1].split("\n### ", 1)[0]
    module = re.search(r"^moon add (\S+)$", section, re.MULTILINE).group(1)
    package = re.search(r"```text\n(.*?)\n```", section, re.DOTALL).group(1)
    source = re.search(r"```moonbit\n(.*?)\n```", section, re.DOTALL).group(1)
    return module, package, source


def run(*args: str, cwd: Path, capture: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, cwd=cwd, check=True, text=True, capture_output=capture)


def main() -> None:
    example = example_from(ROOT / "README.md")
    if example != example_from(ROOT / "README.mbt.md"):
        raise SystemExit("The published-package examples in the two READMEs differ")

    module, package, source = example
    if module != "Noverberrain/configscope@0.1.0":
        raise SystemExit(f"Unexpected published module: {module}")

    with tempfile.TemporaryDirectory(prefix="configscope-consumer-") as directory:
        project = Path(directory)
        (project / "moon.mod").write_text(
            'name = "configscope/consumer-smoke"\n'
            'version = "0.1.0"\n'
            'preferred_target = "wasm"\n',
            encoding="utf-8",
        )
        main_package = project / "cmd" / "main"
        main_package.mkdir(parents=True)
        (main_package / "moon.pkg").write_text(package + "\n", encoding="utf-8")
        (main_package / "main.mbt").write_text(source + "\n", encoding="utf-8")

        # This temp project is outside the checkout, so no local path can mask
        # a missing or broken Mooncakes release.
        run("moon", "add", module, "--no-update", cwd=project)
        run("moon", "check", "--deny-warn", "--warn-list", "+73", cwd=project)
        result = run("moon", "run", "cmd/main", cwd=project, capture=True)
        print(result.stdout, end="")
        if result.stdout.strip() != EXPECTED_OUTPUT:
            raise SystemExit(
                f"Unexpected published-package output: {result.stdout.strip()!r}"
            )


if __name__ == "__main__":
    main()
