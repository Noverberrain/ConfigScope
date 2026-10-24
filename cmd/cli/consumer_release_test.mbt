///|
test "release-check binds defaults to versions and keeps effective changes advisory" {
  let output = match
    @cli.run([
      "configscope", "release-check", "cmd/main/testdata/release/defaults.release.json",
    ]) {
    Ok(text) => text
    Err(error) => fail(error)
  }
  assert_true(output.contains("candidate acceptance: passed"))
  assert_true(output.contains("consumer: \"service\" version: \"v1\""))
  assert_true(output.contains("baseline: \"release-30\""))
  assert_true(
    output.contains(
      "effective: \"timeout\" explicit -> default value_changed=false",
    ),
  )
  assert_true(
    output.contains(
      "effective: \"timeout\" explicit -> default value_changed=true",
    ),
  )
  assert_true(
    output.contains(
      "scope: candidate constraints only; effective changes are advisory",
    ),
  )
}

///|
test "release-check rejection names the version and new violation without values" {
  let output = match
    @cli.run([
      "configscope", "release-check", "cmd/main/testdata/release/rejected.release.json",
    ]) {
    Err(text) => text
    Ok(_) => fail("candidate should be rejected")
  }
  assert_true(output.contains("consumer: \"service\" version: \"v2\""))
  assert_true(output.contains("introduced: above_maximum \"timeout\""))
  assert_true(output.contains("candidate acceptance: failed"))
  assert_true(
    output.contains("effective values: incomparable (invalid snapshot)"),
  )
  assert_eq(output.contains("SENSITIVE_RELEASE_FIXTURE"), false)
  assert_eq(output.contains("45"), false)
}

///|
test "release-check reports missing manifest and manifest-relative files" {
  assert_true(
    @cli.run([
      "configscope", "release-check", "cmd/main/testdata/release/absent.json",
    ])
    is Err(_),
  )
  let output = match
    @cli.run([
      "configscope", "release-check", "cmd/main/testdata/release/missing.release.json",
    ]) {
    Err(text) => text
    Ok(_) => fail("missing candidate should fail")
  }
  assert_eq(output, "contract candidate file 'absent.json' does not exist")
}

///|
test "release-check rejects unsupported options and wrong argument counts" {
  for
    args in [
      ["configscope", "release-check"],
      ["configscope", "release-check", "file.json", "--format", "json", "extra"],
      ["configscope", "release-check", "file.json", "--ignore", "timeout"],
    ] {
    assert_eq(@cli.run(args), Err(@cli.usage()))
  }
}
