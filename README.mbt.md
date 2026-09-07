# ConfigScope

ConfigScope is a MoonBit-native toolkit for explainable layered configuration.
It will merge configuration layers while retaining enough provenance to explain
where every final value came from.

## Current milestone

The project is being built incrementally. The first completed feature is a
simple configuration path type and parser:

```mbt check
///|
test {
  let path = @configscope.parse_path("server.http.port").unwrap()
  inspect(path.length(), content="3")
  inspect(path.to_string(), content="server.http.port")
}
```

Supported now:

- parse dot-separated paths such as `server.port`;
- inspect individual path segments;
- reject empty paths and empty segments.

Not implemented yet: configuration values, layered merge, provenance tracking,
explanations, diff, audit rules, JSON adapters, and the CLI.
