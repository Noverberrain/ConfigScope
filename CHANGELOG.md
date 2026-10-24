# Changelog

## Unreleased

- Add schema-v1 release-check JSON reports with version bindings, regression
  categories, nullable effective-preservation results and shared blocker reasons.
- Keep computed denials machine-readable with exit code 1; leave input errors
  as text and preserve the default text format.

- Add explicit accept/preserve-effective manifest policies with per-version
  blocker codes shared by text reports and exit decisions; fail closed when
  effective comparisons are unavailable under the strict policy.

- Add read-only release-check with explicit version/contract/snapshot bindings,
  manifest-relative paths, strict fields and value-free text attribution.
- Gate candidate acceptance only; effective selection changes remain advisory.

- Analyze per-path required, finite-enumeration and numeric-bound evolution,
  preserving Unknown for unsupported or interacting changes.
- Link a numeric tightening example to version-bound candidate rejection.

- Compare per-version effective selections with default provenance and condition
  activation; expose value-free changes and an opt-in preservation check.
- Treat invalid snapshots as incomparable and fail the preservation check closed.

- Bind consumer versions to contracts and historical snapshots in a library API.
- Attribute introduced, persistent and resolved violations by path and kind.
- Require candidate acceptance across all bindings, including pre-existing issues;
  reject empty support sets and duplicate consumer/version identities.

## 0.5.0 - 2026-10-15

- Add cross-field equality conditions with validated unconditional inputs and
  input defaults. Inactive rules are skipped; invalid references/cycles fail.
- Verify conditional requirements in JSON/combined gates and extend independent
  behavior comparisons to twenty-four cases.
- Add inclusive numeric bounds and integer-only consumer constraints.
- Validate defaults and allowed values against numeric constraints; reject
  non-finite bounds, reversed bounds and empty integer intervals.
- Verify numeric failures through standalone and combined JSON release reports.
- Extend the independent sample consumer with worker-count bounds and defaults.

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
