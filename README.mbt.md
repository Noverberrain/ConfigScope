# ConfigScope

ConfigScope is a MoonBit-native toolkit for explainable layered configuration.
It will merge configuration layers while retaining enough provenance to explain
where every final value came from.

## Current milestone

The project is being built incrementally. Nine foundational features are now
available:

1. simple dot-separated configuration paths;
2. a JSON-compatible configuration value model;
3. nested value lookup through parsed configuration paths;
4. shallow configuration merging with later values taking precedence;
5. recursive merging for nested configuration objects;
6. structural conflict reports for recursive merges;
7. named configuration layers that pair a source name with a value;
8. ordered multi-layer merging with later layers taking precedence;
9. field-level provenance for layered merge results.

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
provenance tracking and `explain` queries will be added in later milestones.

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
Not implemented yet: explanations, diff, audit rules, JSON text adapters, and the CLI.
