///|
test "preserve-effective blocks a changed default under the affected version" {
  let output = match
    @cli.run([
      "configscope", "release-check", "cmd/main/testdata/release/preserve.release.json",
    ]) {
    Err(text) => text
    Ok(_) => fail("effective change must block strict release")
  }
  assert_true(output.contains("policy: preserve-effective"))
  assert_true(output.contains("candidate acceptance: passed"))
  assert_true(output.contains("consumer: \"service\" version: \"v2\""))
  assert_true(output.contains("blocked: effective_value_changed \"timeout\""))
  assert_true(output.contains("release decision: blocked"))
  assert_eq(output.contains("candidate_above_maximum"), false)
}

///|
test "strict policy allows equal explicit to default provenance changes" {
  let output = match
    @cli.run([
      "configscope", "release-check", "cmd/main/testdata/release/preserve-equal.release.json",
    ]) {
    Ok(text) => text
    Err(error) => fail(error)
  }
  assert_true(output.contains("value_changed=false"))
  assert_true(output.contains("release decision: allowed"))
  assert_eq(output.contains("blocked:"), false)
}

///|
test "invalid historical snapshot blocks strict release even when candidate is accepted" {
  let output = match
    @cli.run([
      "configscope", "release-check", "cmd/main/testdata/release/preserve-unknown.release.json",
    ]) {
    Err(text) => text
    Ok(_) => fail("incomparable historical state must block")
  }
  assert_true(output.contains("candidate acceptance: passed"))
  assert_true(output.contains("resolved: above_maximum \"timeout\""))
  assert_true(output.contains("blocked: effective_incomparable"))
  assert_true(output.contains("baseline: \"invalid-history\""))
  assert_true(output.contains("release decision: blocked"))
  assert_eq(output.contains("SENSITIVE_RELEASE_FIXTURE"), false)
}

///|
test "default accept policy retains non-preserving releases and never bypasses violations" {
  let accepted = match
    @cli.run([
      "configscope", "release-check", "cmd/main/testdata/release/defaults.release.json",
    ]) {
    Ok(text) => text
    Err(error) => fail(error)
  }
  assert_true(accepted.contains("policy: accept"))
  assert_true(accepted.contains("release decision: allowed"))
  let rejected = match
    @cli.run([
      "configscope", "release-check", "cmd/main/testdata/release/rejected.release.json",
    ]) {
    Err(text) => text
    Ok(_) => fail("candidate constraints must still block")
  }
  assert_true(rejected.contains("blocked: candidate_above_maximum \"timeout\""))
  assert_true(rejected.contains("release decision: blocked"))
}
