# Changelog

## 0.3.0 - 2026-09-25

- Report the actual number of ignored changes across contract baselines in
  text and JSON output, including zero when rules match nothing.
- Show compatibility contract results in the GitHub Actions run summary and
  retain the value-free JSON report as a downloadable artifact.
- Explicitly attach derived `Eq` and `Debug` methods and qualify black-box
  test imports for the current MoonBit toolchain.

## 0.2.0 - 2026-09-20

- Added deterministic configuration compatibility reports and release gates.
- Added multi-baseline compatibility matrices.
- Added versioned contract manifests with `contract-init` and `contract-check`.
- Added exact-path and trailing `.*` subtree ignore rules.
- Added text and machine-readable JSON reports that avoid exposing values by default.
- Added Windows and Unix demonstration scripts plus published-package CI checks.
- Moved the earlier merge, layering, provenance, and audit foundation behind the
  explicit `Noverberrain/configscope/legacy` package.

## 0.1.0 - 2026-09-15

- Published the initial ConfigScope package with its JSON configuration model,
  path handling, merge foundation, provenance tracking, audits, and tests.
