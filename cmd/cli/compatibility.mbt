///|
/// Render a compatibility report without exposing configuration values.
fn render_compatibility(
  report : @configscope.ConfigCompatibilityReport,
) -> String {
  let lines = report
    .changes()
    .map(change => {
      let path = change.path().to_string()
      let displayed_path = if path == "" { "<root>" } else { path }
      "[" +
      change.impact().to_string() +
      "] " +
      change.difference_kind().to_string() +
      ": " +
      displayed_path
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
  let before = match read_config(args.get(2).unwrap()) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let after = match read_config(args.get(3).unwrap()) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let report = before.compatibility_with(after)
  let output = render_compatibility(report)
  if report.is_compatible() {
    Ok(output + "\ncompatibility check passed")
  } else {
    Err(
      output +
      "\ncompatibility check failed: " +
      report.breaking_count().to_string() +
      " breaking changes detected",
    )
  }
}
