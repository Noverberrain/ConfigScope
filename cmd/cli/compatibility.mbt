///|
/// Parse the impact threshold used by the compatibility release gate.
fn parse_compatibility_policy(
  value : String,
) -> Result[@configscope.ConfigCompatibilityPolicy, String] {
  match value {
    "breaking" => Ok(BreakingOnly)
    "behavioral" => Ok(NoBehavioralChanges)
    "any" => Ok(NoChanges)
    _ =>
      Err(
        "unknown --fail-on value '" +
        value +
        "'; expected breaking, behavioral, or any",
      )
  }
}

///|
/// Parse optional compatibility gate arguments.
fn parse_compatibility_options(
  args : Array[String],
  index : Int,
  policy : @configscope.ConfigCompatibilityPolicy,
) -> Result[@configscope.ConfigCompatibilityPolicy, String] {
  if index >= args.length() {
    Ok(policy)
  } else {
    match args.get(index) {
      Some("--fail-on") =>
        match args.get(index + 1) {
          Some(value) =>
            match parse_compatibility_policy(value) {
              Ok(next_policy) =>
                parse_compatibility_options(args, index + 2, next_policy)
              Err(error) => Err(error)
            }
          None => Err("missing value after --fail-on")
        }
      Some(option) => Err("unknown compat option '" + option + "'")
      None => Err("invalid compat arguments")
    }
  }
}

///|
/// Render a compatibility report without exposing configuration values.
fn render_compatibility(
  report : @configscope.ConfigCompatibilityReport,
  policy : @configscope.ConfigCompatibilityPolicy,
) -> String {
  let lines : Array[String] = ["gate: " + policy.to_string()]
  report
  .changes()
  .each(change => {
    let path = change.path().to_string()
    let displayed_path = if path == "" { "<root>" } else { path }
    lines.push(
      "[" +
      change.impact().to_string() +
      "] " +
      change.difference_kind().to_string() +
      ": " +
      displayed_path,
    )
  })
  lines.push(
    "summary: compatible=" +
    report.compatible_count().to_string() +
    " behavioral=" +
    report.behavioral_count().to_string() +
    " breaking=" +
    report.breaking_count().to_string(),
  )
  lines.join("\n")
}

///|
/// Compare two JSON snapshots and return a CI-friendly compatibility result.
fn run_compat(args : Array[String]) -> Result[String, String] {
  let policy = match parse_compatibility_options(args, 4, BreakingOnly) {
    Ok(policy) => policy
    Err(error) => return Err(error)
  }
  let before = match read_config(args.get(2).unwrap()) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let after = match read_config(args.get(3).unwrap()) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let report = before.compatibility_with(after)
  let output = render_compatibility(report, policy)
  if report.passes(policy) {
    Ok(output + "\ncompatibility check passed")
  } else {
    let count = report.violation_count(policy)
    let noun = if count == 1 { "change" } else { "changes" }
    Err(
      output +
      "\ncompatibility check failed: " +
      count.to_string() +
      " " +
      noun +
      " exceed the '" +
      policy.to_string() +
      "' gate",
    )
  }
}
