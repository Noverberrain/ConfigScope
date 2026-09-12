# ConfigScope

ConfigScope is a MoonBit-native configuration contract compatibility checker.
It compares two materialized JSON configuration snapshots and identifies which
changes are compatible, behavioral, or breaking before a service is released.

## Current direction

The project is being refocused from general configuration merging to one
specific release-safety problem: can a new configuration version still be used
by the existing application contract?

The first compatibility milestone provides:

1. deterministic recursive comparison of JSON-compatible configuration values;
2. stable classification of added, changed, removed, and type-changed paths;
3. a compatibility report with counts, paths, before/after values, and messages;
4. a public API and CLI release gate with configurable breaking, behavioral,
   or all-change thresholds.

The existing path, value, merge, provenance, and audit code is retained as a
reusable JSON foundation during the migration. It is not the new project's
primary promise.

## Scope boundary

ConfigScope consumes already materialized JSON values. It does not implement an
INI/Properties parser, runtime layer resolution, secret loading, or general
schema validation. Those concerns can be handled by a configuration loader;
ConfigScope focuses on compatibility between released configuration versions.

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

The sections below document the reusable JSON foundation retained during this
transition. They are not the project's differentiating scope.

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
  let production = @configscope.ConfigLayer::new("production", value)
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
  let defaults = @configscope.ConfigLayer::new(
    "defaults",
    @configscope.ConfigValue::object(
      Map([("port", @configscope.ConfigValue::number(80.0))]),
    ),
  )
  let production = @configscope.ConfigLayer::new(
    "production",
    @configscope.ConfigValue::object(
      Map([("port", @configscope.ConfigValue::number(8080.0))]),
    ),
  )
  let config = @configscope.LayeredConfig::new([defaults, production])
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
  let defaults = @configscope.ConfigLayer::new(
    "defaults",
    @configscope.ConfigValue::object(
      Map([("port", @configscope.ConfigValue::number(80.0))]),
    ),
  )
  let production = @configscope.ConfigLayer::new(
    "production",
    @configscope.ConfigValue::object(
      Map([("port", @configscope.ConfigValue::number(8080.0))]),
    ),
  )
  let result = @configscope.LayeredConfig::new([defaults, production])
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
  let layer = @configscope.ConfigLayer::new(
    "production",
    @configscope.ConfigValue::object(
      Map([("port", @configscope.ConfigValue::number(8080.0))]),
    ),
  )
  let result = @configscope.LayeredConfig::new([layer])
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
    @configscope.ConfigAuditRule::required(
      @configscope.parse_path("server.host").unwrap(),
    ),
    @configscope.ConfigAuditRule::required(
      @configscope.parse_path("server.port").unwrap(),
    ),
    @configscope.ConfigAuditRule::type_is(
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

### Existing utility commands

The repository still includes `get`, `audit`, and `merge` commands as migration
foundation examples. They are retained for exercising the JSON value model, but
the new project direction is the compatibility report above.

#### The `get` command

The first CLI command reads a JSON file, resolves a dot-separated path, and
prints the selected value as JSON:

```text
moon run cmd/main -- get cmd/main/testdata/basic.json server.port
8080
```

It also supports nested arrays and scalar values, so the same command can query
`features` and receive `["audit","diff"]` as JSON output. Missing paths and
invalid command arguments produce a diagnostic instead of a value.

#### The `audit` command

The audit command applies one or more required-path or type rules to a JSON
file. It reports every issue in path order and exits with status `1` when a
rule fails:

```text
moon run cmd/main -- audit cmd/main/testdata/basic.json --required server.host --type server.port:number
audit passed
```

#### The `merge` command

The merge command reads JSON files from first to last and prints the recursively
merged configuration. Later files override scalar and array values, while
nested objects retain fields from both layers:

```text
moon run cmd/main -- merge cmd/main/testdata/basic.json cmd/main/testdata/production.json
{"server":{"host":"localhost","port":9090},"features":["audit","diff","merge"],"logging":{"level":"info"}}
```

Next planned: versioned contract files and a GitHub Actions release gate.
