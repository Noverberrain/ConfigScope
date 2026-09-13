///|
test "contract-check resolves paths relative to the manifest" {
  assert_eq(
    @cli.run([
      "configscope", "contract-check", "cmd/main/testdata/configscope-compatible.contract.json",
    ]),
    Ok(
      "contract: cmd/main/testdata/configscope-compatible.contract.json\n" +
      "candidate: compatibility-compatible.json\n" +
      "gate: breaking\n" +
      "baseline: basic.json\n" +
      "  [behavioral] changed: features\n" +
      "  [compatible] added: logging\n" +
      "  [behavioral] changed: server.port\n" +
      "result: passed\n" +
      "summary: passed=1 failed=0 total=1\n" +
      "compatibility contract passed",
    ),
  )
}

///|
test "contract-check applies the manifest release gate" {
  assert_eq(
    @cli.run([
      "configscope", "contract-check", "cmd/main/testdata/configscope-breaking.contract.json",
    ]),
    Err(
      "contract: cmd/main/testdata/configscope-breaking.contract.json\n" +
      "candidate: compatibility-breaking.json\n" +
      "gate: breaking\n" +
      "baseline: basic.json\n" +
      "  [breaking] removed: features\n" +
      "  [breaking] type_changed: server.port\n" +
      "result: failed (2 gate violations)\n" +
      "summary: passed=0 failed=1 total=1\n" +
      "compatibility contract failed: 1 baseline exceeds the 'breaking' gate",
    ),
  )
}

///|
test "contract-check reports invalid manifests" {
  assert_eq(
    @cli.run(["configscope", "contract-check", "cmd/main/testdata/basic.json"]),
    Err(
      "invalid compatibility contract 'cmd/main/testdata/basic.json': " +
      "contract is missing required field 'candidate'",
    ),
  )
}

///|
test "contract-check reports missing referenced snapshots" {
  assert_eq(
    @cli.run([
      "configscope", "contract-check", "cmd/main/testdata/configscope-missing.contract.json",
    ]),
    Err("contract candidate file 'missing.json' does not exist"),
  )
}
