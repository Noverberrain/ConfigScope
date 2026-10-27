///|
fn cli_evolution_json(
  before : String,
  after : String,
) -> @configscope.ConfigValue raise {
  let output = match
    @cli.run([
      "configscope",
      "contract-evolve",
      "cmd/main/testdata/evolution/" + before + ".json",
      "cmd/main/testdata/evolution/" + after + ".json",
      "--format",
      "json",
    ]) {
    Ok(output) => output
    Err(error) => fail(error)
  }
  let report = @configscope.ConfigValue::parse_json(output)
  assert_eq(
    report.field("kind").unwrap().as_string(),
    Some("contract_evolution_report"),
  )
  assert_eq(report.field("schema_version").unwrap().as_number(), Some(1.0))
  assert_eq(
    report.field("scope").unwrap().as_string(),
    Some("per_declared_path"),
  )
  assert_eq(
    report.field("analysis_completed").unwrap().as_boolean(),
    Some(true),
  )
  assert_eq(report.field("is_release_gate").unwrap().as_boolean(), Some(false))
  assert_eq(report.contains_field("passed"), false)
  assert_eq(report.contains_field("compatible"), false)
  report
}

///|
test "contract-evolve compares both directions without turning tightening into a release failure" {
  let narrowed = cli_evolution_json("old", "new")
  let widened = cli_evolution_json("new", "old")
  assert_eq(
    narrowed.field("summary").unwrap().field("tightened").unwrap().as_number(),
    Some(2.0),
  )
  assert_eq(
    widened.field("summary").unwrap().field("relaxed").unwrap().as_number(),
    Some(2.0),
  )
  let changes = narrowed.field("changes").unwrap()
  assert_eq(
    changes.element(0).unwrap().field("path").unwrap().as_string(),
    Some("mode"),
  )
  assert_eq(
    changes.element(0).unwrap().field("reason").unwrap().as_string(),
    Some("allowed_values"),
  )
  assert_eq(
    changes.element(1).unwrap().field("path").unwrap().as_string(),
    Some("timeout"),
  )
  assert_eq(
    changes.element(1).unwrap().field("reason").unwrap().as_string(),
    Some("numeric_bounds"),
  )
}

///|
test "Unknown remains a completed diagnostic instead of a compatibility pass" {
  let report = cli_evolution_json("old", "unknown")
  assert_eq(
    report.field("summary").unwrap().field("unknown").unwrap().as_number(),
    Some(1.0),
  )
  assert_eq(
    report
    .field("changes")
    .unwrap()
    .element(0)
    .unwrap()
    .field("reason")
    .unwrap()
    .as_string(),
    Some("default_changed"),
  )
}

///|
test "contract-evolve distinguishes unchanged syntax equivalent sets and incomparable bounds" {
  let unchanged = cli_evolution_json("old", "old")
  assert_eq(unchanged.field("changes").unwrap().length(), Some(0))
  assert_eq(
    unchanged.field("summary").unwrap().field("total").unwrap().as_number(),
    Some(0.0),
  )
  let equivalent = cli_evolution_json("old", "equivalent")
  assert_eq(
    equivalent
    .field("summary")
    .unwrap()
    .field("equivalent")
    .unwrap()
    .as_number(),
    Some(1.0),
  )
  let shifted = cli_evolution_json("old", "shifted")
  assert_eq(
    shifted.field("summary").unwrap().field("incomparable").unwrap().as_number(),
    Some(1.0),
  )
}

///|
test "contract-evolve text and JSON expose no rule values" {
  let before = "cmd/main/testdata/evolution/old.json"
  let after = "cmd/main/testdata/evolution/new.json"
  let default = @cli.run(["configscope", "contract-evolve", before, after])
  assert_eq(
    default,
    @cli.run([
      "configscope", "contract-evolve", before, after, "--format", "text",
    ]),
  )
  let text = match default {
    Ok(v) => v
    Err(e) => fail(e)
  }
  assert_true(text.contains("[tightened] \"timeout\" reason=numeric_bounds"))
  assert_true(text.contains("not a release gate"))
  assert_eq(text.contains("safe"), false)
  let json = cli_evolution_json("old", "new").to_json_string()
  assert_eq(json.contains("safe"), false)
  assert_eq(json.contains("fast"), false)
  assert_eq(json.contains("60"), false)
}

///|
test "contract-evolve reports missing files and invalid old or new contracts as text" {
  let valid = "cmd/main/testdata/evolution/old.json"
  let invalid = "cmd/main/testdata/basic.json"
  assert_eq(
    @cli.run([
      "configscope", "contract-evolve", "missing-evolution.json", valid, "--format",
      "json",
    ]),
    Err("file 'missing-evolution.json' does not exist"),
  )
  assert_eq(
    @cli.run(["configscope", "contract-evolve", invalid, valid]),
    Err("invalid before consumer contract: \"cmd/main/testdata/basic.json\""),
  )
  assert_eq(
    @cli.run(["configscope", "contract-evolve", valid, invalid]),
    Err("invalid after consumer contract: \"cmd/main/testdata/basic.json\""),
  )
}

///|
test "contract-evolve rejects format errors extra arguments and release policy switches" {
  assert_eq(
    @cli.run([
      "configscope", "contract-evolve", "unused", "unused", "--format", "xml",
    ]),
    Err("unknown --format value 'xml'; expected text or json"),
  )
  for
    args in [
      ["configscope", "contract-evolve"],
      ["configscope", "contract-evolve", "old"],
      ["configscope", "contract-evolve", "old", "new", "--format"],
      ["configscope", "contract-evolve", "old", "new", "--policy", "accept"],
      [
        "configscope", "contract-evolve", "old", "new", "--format", "json", "extra",
      ],
    ] {
    assert_eq(@cli.run(args), Err(@cli.usage()))
  }
}
