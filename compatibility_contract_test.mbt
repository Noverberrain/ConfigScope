///|
test "compatibility contract parses paths and default gate" {
  let value = @configscope.ConfigValue::object(
    Map([
      ("candidate", @configscope.ConfigValue::string("configs/v2.json")),
      (
        "baselines",
        @configscope.ConfigValue::array([
          @configscope.ConfigValue::string("configs/v1.json"),
          @configscope.ConfigValue::string("configs/v1.5.json"),
        ]),
      ),
    ]),
  )
  let contract = @configscope.ConfigCompatibilityContract::from_value(value).unwrap()
  assert_eq(contract.candidate_path(), "configs/v2.json")
  assert_eq(contract.baseline_paths(), ["configs/v1.json", "configs/v1.5.json"])
  assert_eq(contract.policy(), BreakingOnly)
  assert_eq(contract.ignored_paths(), [])
}

///|
test "compatibility contract parses exact ignored paths" {
  let value = @configscope.ConfigValue::object(
    Map([
      ("candidate", @configscope.ConfigValue::string("candidate.json")),
      (
        "baselines",
        @configscope.ConfigValue::array([
          @configscope.ConfigValue::string("baseline.json"),
        ]),
      ),
      (
        "ignore_paths",
        @configscope.ConfigValue::array([
          @configscope.ConfigValue::string("build.timestamp"),
          @configscope.ConfigValue::string("metadata.release_id"),
        ]),
      ),
    ]),
  )
  let paths = @configscope.ConfigCompatibilityContract::from_value(value)
    .unwrap()
    .ignored_paths()
  assert_eq(paths.map(path => path.to_string()), [
    "build.timestamp", "metadata.release_id",
  ])
}

///|
test "compatibility contract parses stricter gates" {
  let value = @configscope.ConfigValue::object(
    Map([
      ("candidate", @configscope.ConfigValue::string("candidate.json")),
      (
        "baselines",
        @configscope.ConfigValue::array([
          @configscope.ConfigValue::string("baseline.json"),
        ]),
      ),
      ("fail_on", @configscope.ConfigValue::string("behavioral")),
    ]),
  )
  let contract = @configscope.ConfigCompatibilityContract::from_value(value).unwrap()
  assert_eq(contract.policy(), NoBehavioralChanges)
}

///|
test "compatibility contract rejects a non-object" {
  assert_eq(
    @configscope.ConfigCompatibilityContract::from_value(
      @configscope.ConfigValue::string("not a contract"),
    ),
    Err("contract must be a JSON object"),
  )
}

///|
test "compatibility contract rejects missing required fields" {
  assert_eq(
    @configscope.ConfigCompatibilityContract::from_value(
      @configscope.ConfigValue::object(
        Map([
          (
            "baselines",
            @configscope.ConfigValue::array([
              @configscope.ConfigValue::string("baseline.json"),
            ]),
          ),
        ]),
      ),
    ),
    Err("contract is missing required field 'candidate'"),
  )
  assert_eq(
    @configscope.ConfigCompatibilityContract::from_value(
      @configscope.ConfigValue::object(
        Map([("candidate", @configscope.ConfigValue::string("candidate.json"))]),
      ),
    ),
    Err("contract is missing required field 'baselines'"),
  )
}

///|
test "compatibility contract validates baseline entries" {
  assert_eq(
    @configscope.ConfigCompatibilityContract::from_value(
      @configscope.ConfigValue::object(
        Map([
          ("candidate", @configscope.ConfigValue::string("candidate.json")),
          ("baselines", @configscope.ConfigValue::array([])),
        ]),
      ),
    ),
    Err("contract field 'baselines' must be a non-empty array"),
  )
  assert_eq(
    @configscope.ConfigCompatibilityContract::from_value(
      @configscope.ConfigValue::object(
        Map([
          ("candidate", @configscope.ConfigValue::string("candidate.json")),
          (
            "baselines",
            @configscope.ConfigValue::array([
              @configscope.ConfigValue::number(1.0),
            ]),
          ),
        ]),
      ),
    ),
    Err("contract baseline at index 0 must be a non-empty string"),
  )
  assert_eq(
    @configscope.ConfigCompatibilityContract::from_value(
      @configscope.ConfigValue::object(
        Map([
          ("candidate", @configscope.ConfigValue::string("candidate.json")),
          (
            "baselines",
            @configscope.ConfigValue::array([
              @configscope.ConfigValue::string("baseline.json"),
              @configscope.ConfigValue::string("baseline.json"),
            ]),
          ),
        ]),
      ),
    ),
    Err("contract field 'baselines' contains duplicate path 'baseline.json'"),
  )
}

///|
test "compatibility contract validates the release gate" {
  let value = @configscope.ConfigValue::object(
    Map([
      ("candidate", @configscope.ConfigValue::string("candidate.json")),
      (
        "baselines",
        @configscope.ConfigValue::array([
          @configscope.ConfigValue::string("baseline.json"),
        ]),
      ),
      ("fail_on", @configscope.ConfigValue::string("strict")),
    ]),
  )
  assert_eq(
    @configscope.ConfigCompatibilityContract::from_value(value),
    Err("contract field 'fail_on' must be one of breaking, behavioral, or any"),
  )
}

///|
test "compatibility contract validates ignored paths" {
  fn contract_with(
    ignored : @configscope.ConfigValue,
  ) -> @configscope.ConfigValue {
    @configscope.ConfigValue::object(
      Map([
        ("candidate", @configscope.ConfigValue::string("candidate.json")),
        (
          "baselines",
          @configscope.ConfigValue::array([
            @configscope.ConfigValue::string("baseline.json"),
          ]),
        ),
        ("ignore_paths", ignored),
      ]),
    )
  }

  assert_eq(
    @configscope.ConfigCompatibilityContract::from_value(
      contract_with(@configscope.ConfigValue::string("server.port")),
    ),
    Err("contract field 'ignore_paths' must be an array"),
  )
  assert_eq(
    @configscope.ConfigCompatibilityContract::from_value(
      contract_with(
        @configscope.ConfigValue::array([
          @configscope.ConfigValue::string("server..port"),
        ]),
      ),
    ),
    Err(
      "contract ignored path 'server..port' is invalid: " +
      "configuration path segment 1 must not be empty",
    ),
  )
  assert_eq(
    @configscope.ConfigCompatibilityContract::from_value(
      contract_with(
        @configscope.ConfigValue::array([
          @configscope.ConfigValue::string("server.port"),
          @configscope.ConfigValue::string("server.port"),
        ]),
      ),
    ),
    Err("contract field 'ignore_paths' contains duplicate path 'server.port'"),
  )
}
