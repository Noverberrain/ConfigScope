///|
test "manifest policy rejects null unknown values typos and extra fields" {
  let binding = "{\"consumer\":\"svc\",\"version\":\"v1\",\"baseline_id\":\"b\",\"contract\":\"c\",\"baseline\":\"b\"}"
  let fields = "\"candidate\":\"a\",\"bindings\":[" + binding + "]"
  for policy in ["null", "true", "0", "\"\"", "\"preserve\"", "\"none\""] {
    assert_true(
      parse_release_source("{" + fields + ",\"policy\":" + policy + "}")
      is Err(_),
    )
  }
  assert_true(
    parse_release_source("{" + fields + ",\"polciy\":\"accept\"}") is Err(_),
  )
  assert_true(
    parse_release_source("{" + fields + ",\"policy\":\"accept\",\"skip\":true}")
    is Err(_),
  )
  let explicit = parse_release_source("{" + fields + ",\"policy\":\"accept\"}").unwrap()
  assert_eq(release_policy_label(explicit.policy), "accept")
}

///|
test "policy gate agrees with library acceptance and preservation on valid invalid and changed snapshots" {
  let contract = @configscope.ConfigConsumerContract::from_value(
    @configscope.ConfigValue::parse_json(
      "{\"rules\":[{\"path\":\"n\",\"required\":true,\"type\":\"number\"}]}",
    ),
  ).unwrap()
  for historical in ["{}", "{\"n\":1}"] {
    let binding = @configscope.ConfigConsumerBinding::new(
      "svc",
      "v1",
      "history",
      contract,
      @configscope.ConfigValue::parse_json(historical),
    ).unwrap()
    for candidate in ["{}", "{\"n\":1}", "{\"n\":2}"] {
      let report = @configscope.ConfigConsumerReleaseReport::check(
        [binding],
        @configscope.ConfigValue::parse_json(candidate),
      ).unwrap()
      assert_eq(consumer_release_allowed(report, Accept), report.passes())
      assert_eq(
        consumer_release_allowed(report, PreserveEffective),
        report.passes() && report.preserves_effective_values(),
      )
    }
  }
}

///|
test "strict policy gates conditional state transitions without reporting values" {
  let contract = @configscope.ConfigConsumerContract::from_value(
    @configscope.ConfigValue::parse_json(
      "{\"rules\":[{\"path\":\"enabled\",\"type\":\"boolean\",\"default\":false},{\"path\":\"token\",\"type\":\"string\",\"when\":{\"path\":\"enabled\",\"equals\":true}}]}",
    ),
  ).unwrap()
  let binding = @configscope.ConfigConsumerBinding::new(
    "svc",
    "v1",
    "disabled",
    contract,
    @configscope.ConfigValue::parse_json("{}"),
  ).unwrap()
  let report = @configscope.ConfigConsumerReleaseReport::check(
    [binding],
    @configscope.ConfigValue::parse_json(
      "{\"enabled\":true,\"token\":\"SENSITIVE_POLICY_FIXTURE\"}",
    ),
  ).unwrap()
  assert_eq(consumer_release_allowed(report, Accept), true)
  assert_eq(consumer_release_allowed(report, PreserveEffective), false)
  let text = render_consumer_release(
    "manifest",
    "candidate",
    report,
    [],
    PreserveEffective,
  )
  assert_true(text.contains("blocked: effective_value_changed \"token\""))
  assert_eq(text.contains("SENSITIVE_POLICY_FIXTURE"), false)
}
