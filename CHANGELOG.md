# Changelog

## Unreleased

- Add inclusive numeric bounds and integer-only consumer constraints.
- Validate defaults and allowed values against numeric constraints; reject
  non-finite bounds, reversed bounds and empty integer intervals.
- Verify numeric failures through standalone and combined JSON release reports.
- Extend the independent sample consumer with worker-count bounds and defaults,
  expanding executable behavior comparisons from ten to sixteen cases.

## 0.4.0 - 2026-10-14

- Check declared consumer requirements, JSON types, allowed values and defaults.
- Emit value-free text/JSON consumer reports and combine all manifest consumer
  checks with the structural release gate. Ignore rules affect only differences.
- Reject unknown manifest fields instead of silently ignoring misspelled gates.
- Add an independent sample consumer and ten executable behavior comparisons.
- Clarify retained root `ConfigValue` merge methods and whole-array comparison.

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
- Added a legacy facade for layering, provenance and audit rule/result types.
  Root `ConfigValue` merge methods remain available for source compatibility.

## 0.1.0 - 2026-09-15

- Published the initial ConfigScope package with its JSON configuration model,
  path handling, merge foundation, provenance tracking, audits, and tests.
