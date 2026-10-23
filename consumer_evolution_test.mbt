///|
fn evolution_contract(
  rule : String,
) -> @configscope.ConfigConsumerContract raise {
  @configscope.ConfigConsumerContract::from_value(
    @configscope.ConfigValue::parse_json("{\"rules\":[" + rule + "]}"),
  ).unwrap()
}

///|
fn evolution_change(
  old : String,
  new : String,
) -> @configscope.ConfigContractEvolutionChange raise {
  evolution_contract(old).evolution_to(evolution_contract(new))[0]
}

///|
test "required changes narrow or widen raw input admission" {
  let optional = "{\"path\":\"port\",\"type\":\"number\"}"
  let required = "{\"path\":\"port\",\"type\":\"number\",\"required\":true}"
  let change = evolution_change(optional, required)
  assert_eq(change.impact(), Tightened)
  assert_eq(change.reason(), "required")
  assert_eq(change.path().to_string(), "port")
  assert_eq(evolution_change(required, optional).impact(), Relaxed)
  let empty = @configscope.ConfigValue::parse_json("{}")
  assert_eq(evolution_contract(optional).check(empty).length(), 0)
  assert_eq(evolution_contract(required).check(empty).length(), 1)
}

///|
test "required with an unchanged valid default does not change admission" {
  assert_eq(
    evolution_change(
      "{\"path\":\"port\",\"type\":\"number\",\"default\":80}", "{\"path\":\"port\",\"type\":\"number\",\"default\":80,\"required\":true}",
    ).impact(),
    Equivalent,
  )
}

///|
test "enumerations use set inclusion rather than order or item count" {
  let a = "{\"path\":\"mode\",\"allowed_values\":[\"a\",\"b\"]}"
  let b = "{\"path\":\"mode\",\"allowed_values\":[\"a\"]}"
  assert_eq(evolution_change(a, b).impact(), Tightened)
  assert_eq(evolution_change(b, a).impact(), Relaxed)
  assert_eq(
    evolution_change(a, "{\"path\":\"mode\",\"allowed_values\":[\"b\",\"a\"]}").impact(),
    Equivalent,
  )
  assert_eq(
    evolution_change(a, "{\"path\":\"mode\",\"allowed_values\":[\"b\",\"c\"]}").impact(),
    Incomparable,
  )
}

///|
test "numeric bounds support narrowing widening and shifted intervals" {
  let wide = "{\"path\":\"timeout\",\"type\":\"number\",\"minimum\":1,\"maximum\":60}"
  let narrow = "{\"path\":\"timeout\",\"type\":\"number\",\"minimum\":1,\"maximum\":40}"
  assert_eq(evolution_change(wide, narrow).impact(), Tightened)
  assert_eq(evolution_change(narrow, wide).impact(), Relaxed)
  assert_eq(
    evolution_change(
      wide, "{\"path\":\"timeout\",\"type\":\"number\",\"minimum\":2,\"maximum\":80}",
    ).impact(),
    Incomparable,
  )
  let unbounded = "{\"path\":\"timeout\",\"type\":\"number\"}"
  assert_eq(evolution_change(unbounded, wide).impact(), Tightened)
  assert_eq(evolution_change(wide, unbounded).impact(), Relaxed)
}

///|
test "integer rounding and unchanged enumerations prevent false narrowing" {
  assert_eq(
    evolution_change(
      "{\"path\":\"n\",\"type\":\"number\",\"integer\":true,\"minimum\":1.1,\"maximum\":4.9}",
      "{\"path\":\"n\",\"type\":\"number\",\"integer\":true,\"minimum\":1.9,\"maximum\":4.1}",
    ).impact(),
    Equivalent,
  )
  assert_eq(
    evolution_change(
      "{\"path\":\"n\",\"type\":\"number\",\"allowed_values\":[2,3],\"minimum\":1}",
      "{\"path\":\"n\",\"type\":\"number\",\"allowed_values\":[2,3],\"minimum\":2}",
    ).impact(),
    Equivalent,
  )
}

///|
test "defaults types integer changes and multiple dimensions remain unknown" {
  for
    (old, new) in [
      (
        "{\"path\":\"p\",\"type\":\"number\",\"default\":1}", "{\"path\":\"p\",\"type\":\"number\",\"default\":2}",
      ),
      (
        "{\"path\":\"p\",\"type\":\"number\"}", "{\"path\":\"p\",\"type\":\"string\"}",
      ),
      (
        "{\"path\":\"p\",\"type\":\"number\"}", "{\"path\":\"p\",\"type\":\"number\",\"integer\":true}",
      ),
      (
        "{\"path\":\"p\",\"type\":\"number\"}", "{\"path\":\"p\",\"type\":\"number\",\"required\":true,\"minimum\":1}",
      ),
      (
        "{\"path\":\"p\",\"type\":\"boolean\"}", "{\"path\":\"p\",\"type\":\"boolean\",\"allowed_values\":[true,false]}",
      ),
    ] {
    assert_eq(evolution_change(old, new).impact(), Unknown)
  }
}

///|
test "changed conditional targets are unknown even with simple required changes" {
  let old = evolution_contract(
    "{\"path\":\"enabled\",\"type\":\"boolean\"},{\"path\":\"token\",\"type\":\"string\",\"when\":{\"path\":\"enabled\",\"equals\":true}}",
  )
  let new = evolution_contract(
    "{\"path\":\"enabled\",\"type\":\"boolean\"},{\"path\":\"token\",\"type\":\"string\",\"required\":true,\"when\":{\"path\":\"enabled\",\"equals\":true}}",
  )
  let changes = old.evolution_to(new)
  assert_eq(changes.length(), 1)
  assert_eq(changes[0].impact(), Unknown)
  assert_eq(changes[0].reason(), "conditional_rule")
}

///|
test "overlapping paths are unknown and additions removals are explicit" {
  let old = evolution_contract(
    "{\"path\":\"server\",\"type\":\"object\"},{\"path\":\"server.port\",\"type\":\"number\"}",
  )
  let new = evolution_contract(
    "{\"path\":\"server\",\"type\":\"object\"},{\"path\":\"server.port\",\"type\":\"number\",\"required\":true}",
  )
  assert_eq(old.evolution_to(new)[0].reason(), "overlapping_paths")
  let a = evolution_contract("{\"path\":\"z\",\"type\":\"number\"}")
  let b = evolution_contract("{\"path\":\"a\",\"type\":\"number\"}")
  let changes = a.evolution_to(b)
  assert_eq(changes[0].path().to_string(), "a")
  assert_eq(changes[0].reason(), "rule_added")
  assert_eq(changes[1].reason(), "rule_removed")
  assert_eq(a.evolution_to(a).length(), 0)
}

///|
test "classification agrees with executable admission over a bounded numeric corpus" {
  let rules = [
    "{\"path\":\"n\",\"type\":\"number\",\"minimum\":0,\"maximum\":4}", "{\"path\":\"n\",\"type\":\"number\",\"minimum\":1,\"maximum\":3}",
    "{\"path\":\"n\",\"type\":\"number\",\"minimum\":2,\"maximum\":5}",
  ]
  for a in rules {
    for b in rules {
      let old = evolution_contract(a)
      let new = evolution_contract(b)
      let changes = old.evolution_to(new)
      if changes.is_empty() {
        continue
      }
      let impact = changes[0].impact()
      let mut lost = false
      let mut gained = false
      for number in -1..<7 {
        let value = @configscope.ConfigValue::parse_json(
          "{\"n\":" + number.to_string() + "}",
        )
        let accepted_old = old.check(value).is_empty()
        let accepted_new = new.check(value).is_empty()
        if accepted_old && !accepted_new {
          lost = true
        }
        if !accepted_old && accepted_new {
          gained = true
        }
      }
      match impact {
        Tightened => {
          assert_eq(lost, true)
          assert_eq(gained, false)
        }
        Relaxed => {
          assert_eq(lost, false)
          assert_eq(gained, true)
        }
        Incomparable => {
          assert_eq(lost, true)
          assert_eq(gained, true)
        }
        _ => fail("unexpected classification")
      }
    }
  }
}

///|
test "range tightening links contract evidence to the affected consumer version" {
  let old = evolution_contract(
    "{\"path\":\"timeout\",\"type\":\"number\",\"minimum\":1,\"maximum\":60}",
  )
  let new = evolution_contract(
    "{\"path\":\"timeout\",\"type\":\"number\",\"minimum\":1,\"maximum\":40}",
  )
  let baseline = @configscope.ConfigValue::parse_json("{\"timeout\":30}")
  let candidate = @configscope.ConfigValue::parse_json("{\"timeout\":45}")
  let v1 = @configscope.ConfigConsumerBinding::new(
    "service", "v1", "release-30", old, baseline,
  ).unwrap()
  let v2 = @configscope.ConfigConsumerBinding::new(
    "service", "v2", "release-30", new, baseline,
  ).unwrap()
  assert_eq(old.evolution_to(new)[0].impact(), Tightened)
  let report = @configscope.ConfigConsumerReleaseReport::check(
    [v1, v2],
    candidate,
  ).unwrap()
  assert_eq(report.entries()[0].passes(), true)
  assert_eq(report.entries()[1].version(), "v2")
  assert_eq(report.entries()[1].baseline_id(), "release-30")
  assert_eq(report.entries()[1].introduced()[0].kind(), AboveMaximum)
  assert_eq(report.passes(), false)
}
