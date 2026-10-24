///|
test "JSON issue attribution keeps persistent resolved and introduced distinct" {
  let contract = @configscope.ConfigConsumerContract::from_value(
    @configscope.ConfigValue::parse_json(
      "{\"rules\":[{\"path\":\"a\",\"required\":true,\"type\":\"number\"},{\"path\":\"b\",\"required\":true,\"type\":\"number\"},{\"path\":\"c\",\"required\":true,\"type\":\"number\"}]}",
    ),
  ).unwrap()
  let binding = @configscope.ConfigConsumerBinding::new(
    "svc",
    "v1",
    "history",
    contract,
    @configscope.ConfigValue::parse_json("{\"c\":1}"),
  ).unwrap()
  let report = @configscope.ConfigConsumerReleaseReport::check(
    [binding],
    @configscope.ConfigValue::parse_json("{\"b\":2}"),
  ).unwrap()
  let json = @configscope.ConfigValue::parse_json(
    render_json_consumer_release("m", "c", report, [], Accept),
  )
  let entry = json.field("consumers").unwrap().element(0).unwrap()
  for
    (category, path) in [
      ("persistent", "a"),
      ("resolved", "b"),
      ("introduced", "c"),
    ] {
    let issue = entry.field(category).unwrap().element(0).unwrap()
    assert_eq(issue.field("path").unwrap().as_string(), Some(path))
  }
  assert_eq(entry.field("blockers").unwrap().length(), Some(2))
}

///|
test "JSON labels round trip quotes newlines unicode without raw secret values" {
  let label = "服务\n\"v1\"\\"
  let contract = @configscope.ConfigConsumerContract::from_value(
    @configscope.ConfigValue::parse_json(
      "{\"rules\":[{\"path\":\"token\",\"type\":\"string\"}]}",
    ),
  ).unwrap()
  let binding = @configscope.ConfigConsumerBinding::new(
    label,
    "v1",
    label,
    contract,
    @configscope.ConfigValue::parse_json(
      "{\"token\":\"SENSITIVE_JSON_FIXTURE\"}",
    ),
  ).unwrap()
  let report = @configscope.ConfigConsumerReleaseReport::check(
    [binding],
    @configscope.ConfigValue::parse_json("{\"token\":\"OTHER_SECRET\"}"),
  ).unwrap()
  let text = render_json_consumer_release(
    label,
    "candidate",
    report,
    [],
    PreserveEffective,
  )
  assert_eq(text.contains("SENSITIVE_JSON_FIXTURE"), false)
  assert_eq(text.contains("OTHER_SECRET"), false)
  let json = @configscope.ConfigValue::parse_json(text)
  assert_eq(json.field("manifest").unwrap().as_string(), Some(label))
  assert_eq(
    json
    .field("consumers")
    .unwrap()
    .element(0)
    .unwrap()
    .field("consumer")
    .unwrap()
    .as_string(),
    Some(label),
  )
}
