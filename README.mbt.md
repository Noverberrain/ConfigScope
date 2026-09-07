# ConfigScope

ConfigScope is a MoonBit-native toolkit for explainable layered configuration.
It will merge configuration layers while retaining enough provenance to explain
where every final value came from.

## Current milestone

The project is being built incrementally. Four foundational features are now
available:

1. simple dot-separated configuration paths;
2. a JSON-compatible configuration value model;
3. nested value lookup through parsed configuration paths;
4. shallow configuration merging with later values taking precedence.

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

Not implemented yet: recursive merge, provenance tracking, explanations, diff,
audit rules, JSON text adapters, and the CLI.
