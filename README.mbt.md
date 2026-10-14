# ConfigScope

ConfigScope is a MoonBit-native configuration release checker. Snapshot
differences are heuristic; they do not prove that an application can safely
upgrade. The `consumer-check` command checks explicitly declared consumer
constraints against a candidate JSON snapshot instead.

### Consumer constraints

The declaration at `cmd/main/testdata/consumer.json` specifies required paths,
JSON types, allowed values, and consumer defaults. Try:

```sh
moon run cmd/main -- consumer-check cmd/main/testdata/basic.json cmd/main/testdata/consumer.json
moon run cmd/main -- consumer-check cmd/main/testdata/consumer-invalid.json cmd/main/testdata/consumer.json
moon run cmd/main -- consumer-check cmd/main/testdata/consumer-invalid.json cmd/main/testdata/consumer.json --format json
```

The second command fails on a disallowed value. A pass covers only declared
constraints, not undeclared behavior or cross-field semantics. `compat` remains
a structural gate. `contract-check` additionally validates all rule files in
the optional `consumers` field; without it, only structural checks run.
Defaults apply only when a path is absent, not when it is explicitly `null`.
The consumer must implement its declared defaults; checking does not change
the configuration or supply defaults to an application.

### Numeric constraints (unreleased)

Inclusive `minimum`/`maximum` and `integer: true` require explicit
`type: "number"`. `integer: false` imposes no integer restriction:

```json
{"rules":[{"path":"server.port","required":true,"type":"number","integer":true,"minimum":1,"maximum":65535}]}
```

Defaults and allowed values must also satisfy the numeric constraints. Invalid
or non-finite bounds, reversed bounds and empty integer intervals fail parsing.
The checker distinguishes `not_integer`, `below_minimum`, `above_maximum` and
`non_finite_number`. It reports the first issue per path, checking type, finite
numbers, integers, bounds, then allowed values. Numeric values use IEEE-754
Double; arbitrary precision is not provided. These additions are available in
the checkout but not in published 0.4.0 yet.

### Conditional rules (unreleased)

```json
{"rules":[{"path":"auth.enabled","type":"boolean","default":false},{"path":"auth.token","required":true,"type":"string","when":{"path":"auth.enabled","equals":true}}]}
```

`when` activates the whole target rule on equality with an input governed by
an unconditional rule. That input rule is always checked, and its default is
used only when the input is missing. Explicit null is not replaced; an absent
input without a default cannot match null. No type coercion is performed.
Inactive target rules are skipped. Unknown operators, undeclared/conditional
inputs, cycles and expected values violating the input rule fail parsing.
Only one equality condition per rule is supported. The token rule checks
presence/type, not credential validity. These extensions are unreleased.

### Executable consumer evidence

`examples/service_consumer` directly reads JSON without importing ConfigScope.
It accepts ports 8080/9090, defaults logging to `info`, and reads 1–64 integer
workers with a default of 4, and defaults auth to false. When auth is enabled,
it independently requires a string token.

```sh
moon run examples/service_consumer -- cmd/main/testdata/basic.json
python scripts/check_consumer_behavior.py
```

The script verifies agreement on twenty-four fixed cases and checks the actual default
behavior. This demonstrates this sample's constraints, not arbitrary consumer
behavior. Basic consumer APIs are in the 0.4.0 library; numeric/conditional extensions are
unreleased. CLI examples run from the repository checkout.

## Current direction

The current workflow checks declared consumer expectations alongside structural
differences between released snapshots. It does not infer application behavior
from a difference category.

The first compatibility milestone provides:

1. deterministic recursive comparison of JSON-compatible configuration values;
2. stable classification of added, changed, removed, and type-changed paths;
3. a library difference report with counts, paths, before/after values, and messages;
4. a public API and CLI release gate with configurable breaking, behavioral,
   or all-change thresholds.
5. a compatibility matrix that checks one candidate against multiple historical
   baselines.
6. a versioned contract manifest and `contract-check` command for repeatable
   release checks.
7. a `contract-init` command that generates a portable contract manifest from
   existing JSON snapshots.

The existing JSON foundation is retained for source compatibility. Legacy layer,
provenance, explanation, audit-rule and merge-result type aliases are exported
through `Noverberrain/configscope/legacy`. The root `ConfigValue` still has
historical merge/deep-merge/audit methods. These methods are retained APIs, not
part of the main CLI's release-checking workflow.

## Scope boundary

ConfigScope consumes already materialized JSON values. It does not implement an
INI/Properties parser, runtime layer resolution, secret loading, or general
schema validation. Those concerns can be handled by a configuration loader;
ConfigScope focuses on compatibility between released configuration versions.

### Use from another MoonBit project

The published library is `Noverberrain/configscope@0.4.0`. From the root of
your own MoonBit project, add it as a dependency:

```sh
moon add Noverberrain/configscope@0.4.0
```

Import the root package in the consumer's `cmd/main/moon.pkg`:

```text
import {
  "Noverberrain/configscope",
}

pkgtype(kind: "executable")
```

Then use the public API in `cmd/main/main.mbt`:

```moonbit nocheck
///|
fn main raise {
  let baseline = @configscope.ConfigValue::parse_json(
    "{\"server\":{\"port\":8080},\"features\":[\"audit\"]}",
  )
  let candidate = @configscope.ConfigValue::parse_json(
    "{\"server\":{\"port\":\"9090\"},\"features\":[\"audit\"]}",
  )
  let report = baseline.compatibility_with(candidate)
  println("breaking changes: \{report.breaking_count()}")
  let consumer = @configscope.ConfigConsumerContract::from_value(
    @configscope.ConfigValue::parse_json(
      "{\"rules\":[{\"path\":\"server.port\",\"required\":true,\"type\":\"number\",\"allowed_values\":[8080,9090]}]}",
    ),
  ).unwrap()
  println("consumer violations: \{consumer.check(candidate).length()}")
}
```

Run `moon run cmd/main` from the consumer project. It prints
`breaking changes: 1` and `consumer violations: 1`: `server.port` changes
from a number to a string and violates the declared numeric consumer rule.
The release verification script checks this example in a separate project
using the published package, without a local path dependency. The CLI commands described below
belong to the ConfigScope repository; installing the library does not install
the CLI as a command in the consumer project.

### Configuration compatibility

The baseline model is deliberately small and predictable:

- an added path is `compatible`;
- a changed value is `behavioral`;
- a removed or type-changed path is `breaking`.

```mbt check
///|
test {
  let previous = @configscope.ConfigValue::object(
    Map([("port", @configscope.ConfigValue::number(80.0))]),
  )
  let next = @configscope.ConfigValue::object(
    Map([("port", @configscope.ConfigValue::number(8080.0))]),
  )
  let report = previous.compatibility_with(next)
  inspect(report.breaking_count(), content="0")
  inspect(report.behavioral_count(), content="1")
}
```

The report preserves deterministic path order, and the `compat` command can
fail a release when a selected threshold is exceeded. By default only
`breaking` changes fail; `--fail-on behavioral` also rejects value changes,
while `--fail-on any` requires identical snapshots. The API compares
snapshots; it does not merge runtime layers or read files itself.

### The `compat` command

The `compat` command compares two JSON snapshots. It prints changes without
printing their values, and returns status `1` when the selected gate is not
passed:

```text
moon run cmd/main -- compat cmd/main/testdata/basic.json cmd/main/testdata/compatibility-compatible.json
gate: breaking
[behavioral] changed: features
[compatible] added: logging
[behavioral] changed: server.port
summary: compatible=1 behavioral=2 breaking=0
compatibility check passed
```

This makes the first compatibility check usable as a release gate while keeping
secret values out of the default report. The gate can be tightened with
`--fail-on behavioral` or `--fail-on any` when a release needs a stricter
contract.

### The `compat-matrix` command

The `compat-matrix` command checks a candidate snapshot against every supplied
historical baseline. It keeps the input order, reports each baseline separately,
and fails when any baseline exceeds the selected gate:

```text
moon run cmd/main -- compat-matrix cmd/main/testdata/compatibility-compatible.json cmd/main/testdata/basic.json cmd/main/testdata/compatibility-breaking.json
gate: breaking
baseline: cmd/main/testdata/basic.json
  [behavioral] changed: features
  [compatible] added: logging
  [behavioral] changed: server.port
result: passed
baseline: cmd/main/testdata/compatibility-breaking.json
  [compatible] added: features
  [compatible] added: logging
  [breaking] type_changed: server.port
result: failed (1 gate violation)
summary: passed=1 failed=1 total=2
compatibility matrix failed: 1 baseline exceeds the 'breaking' gate
```

This reports structural differences against several historical snapshots.
Testing expectations of supported consumers requires explicit consumer rules.

### Contract manifests

A contract manifest records the candidate snapshot, the historical baselines,
and the release gate in one reviewable file:

```json
{
  "candidate": "configs/v2.json",
  "baselines": ["configs/v1.json", "configs/v1.5.json"],
  "fail_on": "breaking",
  "ignore_paths": ["build.timestamp", "metadata.*"],
  "consumers": ["consumers/service-v1.json", "consumers/service-v2.json"]
}
```

Run `contract-check` with the manifest path. Snapshot paths are resolved
relative to the manifest, while the report keeps the names written in the
manifest. The `fail_on` field accepts `breaking`, `behavioral`, or `any`
and defaults to `breaking`. This keeps release policy in version control
without adding a configuration loader or a runtime merge mechanism.

The optional `consumers` field is a nonempty array of unique rule-file paths,
resolved relative to the manifest. All consumers and the structural gate must
pass. Ignore rules never suppress consumer violations. Missing rule files,
invalid declarations and unknown manifest fields fail the check. The manifest
is tracked in version control; it has no schema-version negotiation.

The optional `ignore_paths` array excludes known volatile fields from every
baseline comparison. Entries are exact by default; a final `.*` excludes every
descendant of that prefix. For example, `metadata.*` matches
`metadata.release_id` but does not hide a type change at `metadata` itself.
Arbitrary wildcard positions and a global `*` are rejected. Invalid or
duplicate entries make the contract fail validation instead of silently
weakening the release gate.
The contract report shows how many changes were actually ignored across all
baseline comparisons (counting a change once per baseline), including zero
when rules match nothing. JSON output exposes this as `ignored_change_count`.

The repository includes a working example:

```text
moon run cmd/main -- contract-check configscope.contract.json
```

When starting a new release contract, `contract-init` validates the snapshots
and writes the manifest for you. It stores paths relative to the output file,
uses portable `/` separators, and refuses to overwrite an existing file:

```text
moon run cmd/main -- contract-init cmd/main/testdata/compatibility-compatible.json cmd/main/testdata/basic.json --ignore-path build.timestamp --ignore-path 'metadata.*' --output release.contract.json
moon run cmd/main -- contract-check release.contract.json
```

Repeat `--ignore-path` to write reviewed exact paths or trailing `.*` subtree
patterns directly into the generated manifest.

### One-command demonstration

For a complete local demonstration, run the repository script for your shell:

```powershell
.\demo.ps1
```

On Linux or macOS:

```sh
bash demo.sh
```

It generates a temporary contract under `_build/demo`, checks a compatible
release, prints a JSON report, and verifies that the breaking fixture is
rejected with exit code `1`. It also runs the independent sample consumer and
rejects a disallowed value through the combined consumer gate. Build outputs
can be inspected while recording a short project demonstration.

The sections below document the reusable JSON foundation and legacy facade.
They are not the project's
differentiating scope.

### Configuration paths

```mbt check
///|
test {
  let path = @configscope.parse_path("server.http.port").unwrap()
  inspect(path.length(), content="3")
  inspect(path.to_string(), content="server.http.port")
}
```

Paths reject empty input and empty segments such as `server..port`.

### Configuration values

```mbt check
///|
test {
  let server = @configscope.ConfigValue::object(
    Map([
      ("host", @configscope.ConfigValue::string("127.0.0.1")),
      ("port", @configscope.ConfigValue::number(8080.0)),
    ]),
  )
  inspect(server.length().unwrap(), content="2")
  assert_eq(server.field("port").unwrap().as_number().unwrap(), 8080.0)
}
```

The value model supports null, boolean, number, string, array, and object
values. Its internal representation is private, and collection constructors
isolate their top-level input containers.

### Path lookup

```mbt check
///|
test {
  let config = @configscope.ConfigValue::object(
    Map([
      (
        "server",
        @configscope.ConfigValue::object(
          Map([("port", @configscope.ConfigValue::number(8080.0))]),
        ),
      ),
    ]),
  )
  let path = @configscope.parse_path("server.port").unwrap()
  inspect(config.get(path).unwrap().as_number().unwrap(), content="8080")
}
```

Lookup follows object fields only. Missing fields, non-object intermediate values,
and array indexes return `None`.
Difference comparison recurses through objects; arrays are compared as whole
values, with no element-level or index-path rules.

### Shallow merge

```mbt check
///|
test {
  let defaults = @configscope.ConfigValue::object(
    Map([("port", @configscope.ConfigValue::number(80.0))]),
  )
  let environment = @configscope.ConfigValue::object(
    Map([("port", @configscope.ConfigValue::number(8080.0))]),
  )
  let merged = defaults.merge(environment)
  inspect(merged.field("port").unwrap().as_number().unwrap(), content="8080")
}
```

### Recursive merge

```mbt check
///|
test {
  let defaults = @configscope.ConfigValue::object(
    Map([
      (
        "server",
        @configscope.ConfigValue::object(
          Map([("port", @configscope.ConfigValue::number(80.0))]),
        ),
      ),
    ]),
  )
  let production = @configscope.ConfigValue::object(
    Map([
      (
        "server",
        @configscope.ConfigValue::object(
          Map([("host", @configscope.ConfigValue::string("prod"))]),
        ),
      ),
    ]),
  )
  let merged = defaults.deep_merge(production)
  inspect(
    merged
    .get(@configscope.parse_path("server.port").unwrap())
    .unwrap()
    .as_number()
    .unwrap(),
    content="80",
  )
  inspect(
    merged
    .get(@configscope.parse_path("server.host").unwrap())
    .unwrap()
    .as_string()
    .unwrap(),
    content="prod",
  )
}
```

When both values at the same path are objects, their fields are merged
recursively. Later arrays, scalars, and conflicting types replace earlier
values.

### Conflict reports

```mbt check
///|
test {
  let defaults = @configscope.ConfigValue::object(
    Map([
      (
        "limits",
        @configscope.ConfigValue::object(
          Map([("requests", @configscope.ConfigValue::number(100.0))]),
        ),
      ),
    ]),
  )
  let production = @configscope.ConfigValue::object(
    Map([("limits", @configscope.ConfigValue::number(10.0))]),
  )
  let report = defaults.deep_merge_with_report(production)
  inspect(report.conflict_count(), content="1")
  let conflict = report.conflict(0).unwrap()
  inspect(conflict.path().to_string(), content="limits")
  inspect(conflict.earlier_kind().to_string(), content="object")
  inspect(conflict.later_kind().to_string(), content="number")
}
```

Conflict reporting is limited to structural changes between objects and
non-object values. Compatible scalar replacements and array replacements remain
normal later-layer overrides. A conflict at the configuration root uses an
empty path string.

### Named configuration layers

```mbt check
///|
test {
  let value = @configscope.ConfigValue::object(
    Map([("region", @configscope.ConfigValue::string("eu-west"))]),
  )
  let production = @legacy.ConfigLayer::new("production", value)
  inspect(production.name(), content="production")
  inspect(
    production.value().field("region").unwrap().as_string().unwrap(),
    content="eu-west",
  )
}
```

A configuration layer attaches a stable source name to a configuration value.
Ordered collections of these layers can be merged with `LayeredConfig`. Per-field
provenance tracking and `explain` queries are available on merge results.

### Ordered layered merging

```mbt check
///|
test {
  let defaults = @legacy.ConfigLayer::new(
    "defaults",
    @configscope.ConfigValue::object(
      Map([("port", @configscope.ConfigValue::number(80.0))]),
    ),
  )
  let production = @legacy.ConfigLayer::new(
    "production",
    @configscope.ConfigValue::object(
      Map([("port", @configscope.ConfigValue::number(8080.0))]),
    ),
  )
  let config = @legacy.LayeredConfig::new([defaults, production])
    .merge()
    .unwrap()
  inspect(config.field("port").unwrap().as_number().unwrap(), content="8080")
}
```

`LayeredConfig` preserves the supplied order and recursively merges each layer
from first to last. A later layer overrides an earlier value at the same path,
while nested objects retain fields that are not overridden. Use
`merge_with_report()` when structural conflicts should be collected alongside
the merged value. An empty layered configuration returns `None` from either
merge method.

### Field provenance

```mbt check
///|
test {
  let defaults = @legacy.ConfigLayer::new(
    "defaults",
    @configscope.ConfigValue::object(
      Map([("port", @configscope.ConfigValue::number(80.0))]),
    ),
  )
  let production = @legacy.ConfigLayer::new(
    "production",
    @configscope.ConfigValue::object(
      Map([("port", @configscope.ConfigValue::number(8080.0))]),
    ),
  )
  let result = @legacy.LayeredConfig::new([defaults, production])
    .merge_with_provenance()
    .unwrap()
  inspect(
    result.source(@configscope.parse_path("port").unwrap()).unwrap(),
    content="production",
  )
}
```

`merge_with_provenance()` returns the merged value, structural conflicts, and
the layer name that supplied each final configuration path. When nested objects
are merged, unchanged descendants keep their earlier source while overridden
fields receive the later layer's name. Replacing an object with a scalar (or the
reverse) removes stale descendant entries. Empty layered configurations return
`None`.

### Structured explanations

```mbt check
///|
test {
  let layer = @legacy.ConfigLayer::new(
    "production",
    @configscope.ConfigValue::object(
      Map([("port", @configscope.ConfigValue::number(8080.0))]),
    ),
  )
  let result = @legacy.LayeredConfig::new([layer])
    .merge_with_provenance()
    .unwrap()
  let explanation = result
    .explain(@configscope.parse_path("port").unwrap())
    .unwrap()
  inspect(explanation.path().to_string(), content="port")
  inspect(explanation.kind().to_string(), content="number")
  inspect(explanation.source(), content="production")
}
```

`explain(path)` combines the final value, its `ConfigValueKind`, the canonical
path, and the source layer name into one diagnostic result. It returns `None`
when the path is missing or is not represented in the provenance index.

### Configuration differences

```mbt check
///|
test {
  let before = @configscope.ConfigValue::object(
    Map([
      ("host", @configscope.ConfigValue::string("localhost")),
      ("port", @configscope.ConfigValue::number(80.0)),
    ]),
  )
  let after = @configscope.ConfigValue::object(
    Map([
      ("port", @configscope.ConfigValue::number(8080.0)),
      ("tls", @configscope.ConfigValue::boolean(true)),
    ]),
  )
  let differences = before.diff(after)
  inspect(differences.length(), content="3")
  inspect(differences.get(0).unwrap().path().to_string(), content="host")
  inspect(differences.get(0).unwrap().kind().to_string(), content="removed")
}
```

`diff(later)` recursively compares object fields and reports `Added`, `Removed`,
`Changed`, or `TypeChanged` entries. Each entry contains its canonical path and
optional before/after values. Arrays are compared as whole values in this
milestone, and a root-level scalar or type difference uses an empty path string.
Results are ordered lexicographically by path, and equal values produce an empty
difference array.

### Required-path audits

```mbt check
///|
test {
  let value = @configscope.ConfigValue::object(
    Map([
      (
        "server",
        @configscope.ConfigValue::object(
          Map([("host", @configscope.ConfigValue::string("localhost"))]),
        ),
      ),
    ]),
  )
  let issues = value.audit([
    @legacy.ConfigAuditRule::required(
      @configscope.parse_path("server.host").unwrap(),
    ),
    @legacy.ConfigAuditRule::required(
      @configscope.parse_path("server.port").unwrap(),
    ),
    @legacy.ConfigAuditRule::type_is(
      @configscope.parse_path("server.host").unwrap(),
      String,
    ),
  ])
  inspect(issues.length(), content="1")
  inspect(issues.get(0).unwrap().path().to_string(), content="server.port")
  inspect(issues.get(0).unwrap().kind().to_string(), content="missing_required")
}
```

`audit(rules)` applies reusable validation rules to a configuration value. The
`required(path)` rule requires a parsed path to exist. A path whose final value
is `null` still counts as present. The `type_is(path, kind)` rule checks the
kind of an existing value and reports its expected and actual kinds. Type rules
skip missing paths so they can be combined with `required(path)` without
producing duplicate missing-path diagnostics. Issues include a stable kind,
canonical path, and human-readable message, and results are sorted by path.

### Legacy foundation

The legacy facade exports layer, provenance, explanation, audit-rule and
merge-result types. `ConfigValue` methods still belong to the shared JSON type
and can be called through the root package.
The main CLI intentionally exposes only compatibility workflow commands, so
the project's public workflow stays focused on release-time compatibility
checks.

#### Legacy API examples

The historical path API reads a parsed value and resolves a dot-separated path.

```text
`get` is no longer exposed by the main CLI.
The main CLI no longer exposes this command.
```

Nested arrays and scalar values remain covered by the JSON value model; they
are not commands exposed by the primary CLI. Missing paths and
invalid command arguments are handled by the library rather than the primary CLI.

<!-- The legacy command examples are intentionally omitted from the main CLI. -->

The historical audit API applies required-path or type rules to a parsed value.

```text
`audit` is no longer exposed by the main CLI.
The legacy API reports whether its rules pass; the primary CLI does not expose it.
```

#### Historical merge API

The historical layer API is exported through the legacy package; later layers
override nested fields. The root `ConfigValue` still exposes merge methods for
source compatibility.

```text
`merge` is no longer exposed by the main CLI.
`Noverberrain/configscope/legacy`
```

GitHub Actions now runs `contract-check` on pushes and pull requests, so a
breaking change in the checked contract can block the workflow before release.
Its run summary also shows the gate result, per-baseline counts, ignored-change
count, and violating paths without revealing configuration values.
The same run saves the value-free JSON result as the `configscope-contract-report`
Artifact for 14 days, including when the contract gate fails.

### JSON reports

`compat`, `compat-matrix`, `contract-check`, and `consumer-check` accept
`--format json`. `contract-init` generates a manifest without that option:

```text
moon run cmd/main -- contract-check configscope.contract.json --format json
```

Structural reports contain `gate`, counts and ordered changes. Combined
contract reports also contain ordered `consumers` with `passed`, `violations`
and value-free `issues`. `summary` counts baselines, while top-level `passed`
covers both gates. Standalone consumer reports use `kind: consumer_report`,
`scope`, `passed` and `issues`. Computed violations return exit code `1` with
JSON on standard output; argument, file and declaration errors remain text.
