///|
fn parse_release_source(
  source : String,
) -> Result[ConsumerReleaseManifest, String] raise {
  parse_consumer_release_manifest(@configscope.ConfigValue::parse_json(source))
}

///|
test "release manifest rejects unknown fields missing fields and nonobjects" {
  for
    source in [
      "null", "[]", "{}", "{\"candidate\":\"a\",\"bindings\":[]}", "{\"candidate\":\"a\",\"bindings\":[1]}",
      "{\"candidate\":\"a\",\"bindings\":[],\"fail_on\":\"none\"}", "{\"candidate\":null,\"bindings\":[{}]}",
      "{\"candidate\":\"a\",\"bindngs\":[{}]}",
    ] {
    assert_true(parse_release_source(source) is Err(_))
  }
}

///|
test "binding identities are required and duplicate versions are rejected before IO" {
  let valid = "{\"consumer\":\"svc\",\"version\":\"v1\",\"baseline_id\":\"b\",\"contract\":\"c.json\",\"baseline\":\"b.json\"}"
  assert_true(
    parse_release_source(
      "{\"candidate\":\"a.json\",\"bindings\":[" + valid + "]}",
    )
    is Ok(_),
  )
  assert_true(
    parse_release_source(
      "{\"candidate\":\"a.json\",\"bindings\":[" + valid + "," + valid + "]}",
    )
    is Err(_),
  )
  for
    item in [
      "{\"consumer\":\"svc\",\"version\":\" \",\"baseline_id\":\"b\",\"contract\":\"c\",\"baseline\":\"b\"}",
      "{\"consumer\":\"svc\",\"version\":\"v1\",\"baseline_id\":\"b\",\"contract\":\"c\",\"baselin\":\"b\"}",
      "{\"consumer\":\"svc\",\"version\":\"v1\",\"baseline_id\":\"b\",\"contract\":\"c\",\"baseline\":\"b\",\"skip\":true}",
    ] {
    assert_true(
      parse_release_source("{\"candidate\":\"a\",\"bindings\":[" + item + "]}")
      is Err(_),
    )
  }
}

///|
test "release rendering keeps persistent and resolved issues separate and escapes labels" {
  let rules = @configscope.ConfigConsumerContract::from_value(
    @configscope.ConfigValue::parse_json(
      "{\"rules\":[{\"path\":\"port\",\"required\":true,\"type\":\"number\"},{\"path\":\"token\",\"required\":true,\"type\":\"string\"}]}",
    ),
  ).unwrap()
  let binding = @configscope.ConfigConsumerBinding::new(
    "service\nforged",
    "v1",
    "history",
    rules,
    @configscope.ConfigValue::parse_json("{}"),
  ).unwrap()
  let report = @configscope.ConfigConsumerReleaseReport::check(
    [binding],
    @configscope.ConfigValue::parse_json("{\"port\":80}"),
  ).unwrap()
  let output = render_consumer_release(
    "manifest",
    "candidate",
    report,
    [],
    Accept,
  )
  assert_true(output.contains("persistent: missing_required \"token\""))
  assert_true(output.contains("resolved: missing_required \"port\""))
  assert_true(output.contains("service\\nforged"))
  assert_eq(output.contains("service\nforged"), false)
}
