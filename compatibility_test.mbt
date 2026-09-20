// Black-box tests for configuration contract compatibility.

///|
test "compatibility classifies snapshot changes" {
  let before = @configscope.ConfigValue::object(
    Map([
      ("removed", @configscope.ConfigValue::string("old")),
      ("port", @configscope.ConfigValue::number(80.0)),
      ("logging", @configscope.ConfigValue::string("compact")),
    ]),
  )
  let after = @configscope.ConfigValue::object(
    Map([
      ("added", @configscope.ConfigValue::boolean(true)),
      ("port", @configscope.ConfigValue::number(8080.0)),
      (
        "logging",
        @configscope.ConfigValue::object(
          Map([("format", @configscope.ConfigValue::string("json"))]),
        ),
      ),
    ]),
  )
  let report = before.compatibility_with(after)
  assert_eq(report.change_count(), 4)
  assert_eq(report.compatible_count(), 1)
  assert_eq(report.behavioral_count(), 1)
  assert_eq(report.breaking_count(), 2)
  assert_true(!report.is_compatible())
  assert_eq(report.change(0).unwrap().path().to_string(), "added")
  assert_eq(report.change(0).unwrap().impact(), Compatible)
  assert_eq(report.change(1).unwrap().path().to_string(), "logging")
  assert_eq(report.change(1).unwrap().impact(), Breaking)
  assert_eq(report.change(2).unwrap().path().to_string(), "port")
  assert_eq(report.change(2).unwrap().impact(), Behavioral)
  assert_eq(report.change(3).unwrap().path().to_string(), "removed")
  assert_eq(report.change(3).unwrap().impact(), Breaking)
}

///|
test "compatibility exposes original values and messages" {
  let before = @configscope.ConfigValue::object(
    Map([("port", @configscope.ConfigValue::number(80.0))]),
  )
  let after = @configscope.ConfigValue::object(
    Map([("port", @configscope.ConfigValue::string("8080"))]),
  )
  let change = before.compatibility_with(after).change(0).unwrap()
  assert_eq(change.difference_kind(), TypeChanged)
  assert_eq(change.before().unwrap().as_number().unwrap(), 80.0)
  assert_eq(change.after().unwrap().as_string().unwrap(), "8080")
  assert_eq(change.message(), "configuration path 'port' changed type")
}

///|
test "compatibility impact names are stable" {
  assert_eq(
    @configscope.ConfigCompatibilityImpact::Compatible.to_string(),
    "compatible",
  )
  assert_eq(
    @configscope.ConfigCompatibilityImpact::Behavioral.to_string(),
    "behavioral",
  )
  assert_eq(
    @configscope.ConfigCompatibilityImpact::Breaking.to_string(),
    "breaking",
  )
}

///|
test "equal snapshots are compatible" {
  let value = @configscope.ConfigValue::object(
    Map([("enabled", @configscope.ConfigValue::boolean(true))]),
  )
  let report = value.compatibility_with(value)
  assert_eq(report.change_count(), 0)
  assert_eq(report.breaking_count(), 0)
  assert_true(report.is_compatible())
}

///|
test "compatibility policies count violations at each threshold" {
  let before = @configscope.ConfigValue::object(
    Map([
      ("added", @configscope.ConfigValue::string("old")),
      ("removed", @configscope.ConfigValue::string("old")),
      ("port", @configscope.ConfigValue::number(80.0)),
    ]),
  )
  let after = @configscope.ConfigValue::object(
    Map([
      ("added", @configscope.ConfigValue::string("new")),
      ("port", @configscope.ConfigValue::number(8080.0)),
      ("enabled", @configscope.ConfigValue::boolean(true)),
    ]),
  )
  let report = before.compatibility_with(after)
  assert_eq(report.violation_count(BreakingOnly), 1)
  assert_eq(report.violation_count(NoBehavioralChanges), 3)
  assert_eq(report.violation_count(NoChanges), 4)
  assert_true(report.passes(BreakingOnly) == false)
  assert_true(report.passes(NoBehavioralChanges) == false)
  assert_true(report.passes(NoChanges) == false)
}

///|
test "compatibility policy names are stable" {
  assert_eq(
    @configscope.ConfigCompatibilityPolicy::BreakingOnly.to_string(),
    "breaking",
  )
  assert_eq(
    @configscope.ConfigCompatibilityPolicy::NoBehavioralChanges.to_string(),
    "behavioral",
  )
  assert_eq(
    @configscope.ConfigCompatibilityPolicy::NoChanges.to_string(),
    "any",
  )
}

///|
test "compatibility matrix preserves baselines and applies a policy" {
  let candidate = @configscope.ConfigValue::object(
    Map([("port", @configscope.ConfigValue::number(8080.0))]),
  )
  let stable_baseline = @configscope.ConfigCompatibilityBaseline::new(
    "v1",
    @configscope.ConfigValue::object(
      Map([("port", @configscope.ConfigValue::number(80.0))]),
    ),
  )
  let breaking_baseline = @configscope.ConfigCompatibilityBaseline::new(
    "v2",
    @configscope.ConfigValue::object(
      Map([("port", @configscope.ConfigValue::string("8080"))]),
    ),
  )
  let matrix = candidate.compatibility_matrix([
    stable_baseline, breaking_baseline,
  ])
  assert_eq(matrix.baseline_count(), 2)
  assert_eq(matrix.passed_count(BreakingOnly), 1)
  assert_eq(matrix.failed_count(BreakingOnly), 1)
  assert_true(!matrix.passes(BreakingOnly))
  assert_eq(matrix.entry(0).unwrap().baseline_name(), "v1")
  assert_true(matrix.entry(0).unwrap().passes(BreakingOnly))
  assert_eq(matrix.entry(1).unwrap().baseline_name(), "v2")
  assert_eq(
    matrix.entry(1).unwrap().report().change(0).unwrap().difference_kind(),
    TypeChanged,
  )
}

///|
test "empty compatibility matrix passes every policy" {
  let candidate = @configscope.ConfigValue::empty_object()
  let matrix = candidate.compatibility_matrix([])
  assert_eq(matrix.baseline_count(), 0)
  assert_true(matrix.passes(BreakingOnly))
  assert_true(matrix.passes(NoBehavioralChanges))
  assert_true(matrix.passes(NoChanges))
}

///|
test "compatibility reports exclude only exact paths" {
  let before = @configscope.ConfigValue::object(
    Map([
      (
        "metadata",
        @configscope.ConfigValue::object(
          Map([("release_id", @configscope.ConfigValue::string("old"))]),
        ),
      ),
      ("port", @configscope.ConfigValue::number(80.0)),
    ]),
  )
  let after = @configscope.ConfigValue::object(
    Map([
      (
        "metadata",
        @configscope.ConfigValue::object(
          Map([("release_id", @configscope.ConfigValue::string("new"))]),
        ),
      ),
      ("port", @configscope.ConfigValue::string("80")),
    ]),
  )
  let report = before.compatibility_with(after)
  let parent_only = report.excluding_paths([
    @configscope.parse_path("metadata").unwrap(),
  ])
  assert_eq(parent_only.change_count(), 2)
  let exact = report.excluding_paths([
    @configscope.parse_path("metadata.release_id").unwrap(),
  ])
  assert_eq(exact.change_count(), 1)
  assert_eq(exact.change(0).unwrap().path().to_string(), "port")
}

///|
test "compatibility matrix excludes paths from every baseline" {
  let candidate = @configscope.ConfigValue::object(
    Map([("port", @configscope.ConfigValue::string("8080"))]),
  )
  let baseline = @configscope.ConfigCompatibilityBaseline::new(
    "v1",
    @configscope.ConfigValue::object(
      Map([("port", @configscope.ConfigValue::number(8080.0))]),
    ),
  )
  let matrix = candidate
    .compatibility_matrix([baseline])
    .excluding_paths([@configscope.parse_path("port").unwrap()])
  assert_true(matrix.passes(BreakingOnly))
  assert_eq(matrix.entry(0).unwrap().report().change_count(), 0)
}

///|
test "compatibility reports support trailing subtree patterns" {
  let before = @configscope.ConfigValue::object(
    Map([
      (
        "metadata",
        @configscope.ConfigValue::object(
          Map([
            ("release_id", @configscope.ConfigValue::string("old")),
            ("timestamp", @configscope.ConfigValue::number(1.0)),
          ]),
        ),
      ),
      ("metadata2", @configscope.ConfigValue::string("old")),
    ]),
  )
  let after = @configscope.ConfigValue::object(
    Map([
      (
        "metadata",
        @configscope.ConfigValue::object(
          Map([
            ("release_id", @configscope.ConfigValue::string("new")),
            ("timestamp", @configscope.ConfigValue::number(2.0)),
          ]),
        ),
      ),
      ("metadata2", @configscope.ConfigValue::string("new")),
    ]),
  )
  let report = before
    .compatibility_with(after)
    .excluding_path_patterns([@configscope.parse_path("metadata.*").unwrap()])
  assert_eq(report.change_count(), 1)
  assert_eq(report.change(0).unwrap().path().to_string(), "metadata2")
}

///|
test "subtree patterns do not exclude the prefix itself" {
  let before = @configscope.ConfigValue::object(
    Map([("metadata", @configscope.ConfigValue::string("old"))]),
  )
  let after = @configscope.ConfigValue::object(
    Map([
      (
        "metadata",
        @configscope.ConfigValue::object(
          Map([("release_id", @configscope.ConfigValue::string("new"))]),
        ),
      ),
    ]),
  )
  let report = before
    .compatibility_with(after)
    .excluding_path_patterns([@configscope.parse_path("metadata.*").unwrap()])
  assert_eq(report.change_count(), 1)
  assert_eq(report.change(0).unwrap().path().to_string(), "metadata")
}
