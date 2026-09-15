///|
test "contract-init renders paths relative to its output file" {
  let output = render_contract_init_manifest(
    "generated/configscope.contract.json",
    "cmd/main/testdata/compatibility-compatible.json",
    ["cmd/main/testdata/basic.json"],
    NoBehavioralChanges,
  )
  let value = @configscope.ConfigValue::parse_json(output)
  assert_eq(
    value.field("candidate").unwrap().as_string(),
    Some("../cmd/main/testdata/compatibility-compatible.json"),
  )
  assert_eq(
    value.field("baselines").unwrap().element(0).unwrap().as_string(),
    Some("../cmd/main/testdata/basic.json"),
  )
  assert_eq(value.field("fail_on").unwrap().as_string(), Some("behavioral"))
}

///|
test "contract-init creates a contract that contract-check can consume" {
  let output = "cmd/main/testdata/contract-init-test.contract.json"
  if @fs.path_exists(output) {
    ignore(@fs.remove_file(output) catch { _ => () })
  }
  let result = run([
    "configscope", "contract-init", "cmd/main/testdata/compatibility-compatible.json",
    "cmd/main/testdata/basic.json", "--output", output,
  ])
  assert_true(result is Ok(_))
  let generated = try! @fs.read_file_to_string(output)
  let manifest = @configscope.ConfigValue::parse_json(generated)
  assert_eq(
    manifest.field("candidate").unwrap().as_string(),
    Some("compatibility-compatible.json"),
  )
  assert_eq(
    manifest.field("baselines").unwrap().element(0).unwrap().as_string(),
    Some("basic.json"),
  )
  let check = run(["configscope", "contract-check", output]).unwrap()
  assert_true(check.has_suffix("compatibility contract passed"))
  try! @fs.remove_file(output)
}

///|
test "contract-init validates inputs before writing" {
  assert_eq(
    run([
      "configscope", "contract-init", "cmd/main/testdata/missing.json", "cmd/main/testdata/basic.json",
      "--output", "cmd/main/testdata/contract-init-missing-test.json",
    ]),
    Err("file 'cmd/main/testdata/missing.json' does not exist"),
  )
  assert_eq(
    run([
      "configscope", "contract-init", "cmd/main/testdata/compatibility-compatible.json",
      "cmd/main/testdata/basic.json", "cmd/main/testdata/basic.json", "--output",
      "cmd/main/testdata/contract-init-duplicate-test.json",
    ]),
    Err(
      "contract-init received duplicate baseline 'cmd/main/testdata/basic.json'",
    ),
  )
}

///|
test "contract-init refuses to overwrite a contract" {
  assert_eq(
    run([
      "configscope", "contract-init", "cmd/main/testdata/compatibility-compatible.json",
      "cmd/main/testdata/basic.json", "--output", "configscope.contract.json",
    ]),
    Err(
      "contract output file 'configscope.contract.json' already exists; choose another path",
    ),
  )
}
