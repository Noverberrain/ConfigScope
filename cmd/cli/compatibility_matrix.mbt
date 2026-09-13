///|
/// Command-line arguments for a compatibility matrix check.
priv struct CompatibilityMatrixArguments {
  baseline_paths : Array[String]
  policy : @configscope.ConfigCompatibilityPolicy
}

///|
/// Parse baseline files and the optional release gate.
fn parse_compatibility_matrix_arguments(
  args : Array[String],
  index : Int,
  baseline_paths : Array[String],
  policy : @configscope.ConfigCompatibilityPolicy,
) -> Result[CompatibilityMatrixArguments, String] {
  if index >= args.length() {
    if baseline_paths.length() == 0 {
      Err("compat-matrix requires at least one baseline file")
    } else {
      Ok({ baseline_paths, policy })
    }
  } else {
    match args.get(index) {
      Some("--fail-on") =>
        match args.get(index + 1) {
          Some(value) =>
            match parse_compatibility_policy(value) {
              Ok(next_policy) =>
                match
                  parse_compatibility_options(args, index + 2, next_policy) {
                  Ok(final_policy) =>
                    if baseline_paths.length() == 0 {
                      Err("compat-matrix requires at least one baseline file")
                    } else {
                      Ok({ baseline_paths, policy: final_policy })
                    }
                  Err(error) => Err(error)
                }
              Err(error) => Err(error)
            }
          None => Err("missing value after --fail-on")
        }
      Some(path) => {
        baseline_paths.push(path)
        parse_compatibility_matrix_arguments(
          args,
          index + 1,
          baseline_paths,
          policy,
        )
      }
      None => Err("invalid compat-matrix arguments")
    }
  }
}

///|
/// Read all named baseline snapshots in input order.
fn read_compatibility_baselines(
  paths : Array[String],
  index : Int,
  baselines : Array[@configscope.ConfigCompatibilityBaseline],
) -> Result[Array[@configscope.ConfigCompatibilityBaseline], String] {
  if index >= paths.length() {
    Ok(baselines)
  } else {
    let path = paths.get(index).unwrap()
    match read_config(path) {
      Ok(value) => {
        baselines.push(
          @configscope.ConfigCompatibilityBaseline::new(path, value),
        )
        read_compatibility_baselines(paths, index + 1, baselines)
      }
      Err(error) => Err(error)
    }
  }
}

///|
/// Render a matrix change without exposing configuration values.
fn render_matrix_change(
  change : @configscope.ConfigCompatibilityChange,
) -> String {
  let path = change.path().to_string()
  let displayed_path = if path == "" { "<root>" } else { path }
  "  [" +
  change.impact().to_string() +
  "] " +
  change.difference_kind().to_string() +
  ": " +
  displayed_path
}

///|
/// Render a compatibility matrix without exposing configuration values.
fn render_compatibility_matrix(
  report : @configscope.ConfigCompatibilityMatrixReport,
  policy : @configscope.ConfigCompatibilityPolicy,
) -> String {
  let lines : Array[String] = ["gate: " + policy.to_string()]
  report
  .entries()
  .each(entry => {
    lines.push("baseline: " + entry.baseline_name())
    entry
    .report()
    .changes()
    .each(change => lines.push(render_matrix_change(change)))
    let violation_count = entry.violation_count(policy)
    let result = if violation_count == 0 {
      "passed"
    } else {
      let noun = if violation_count == 1 { "violation" } else { "violations" }
      "failed (" + violation_count.to_string() + " gate " + noun + ")"
    }
    lines.push("result: " + result)
  })
  lines.push(
    "summary: passed=" +
    report.passed_count(policy).to_string() +
    " failed=" +
    report.failed_count(policy).to_string() +
    " total=" +
    report.baseline_count().to_string(),
  )
  lines.join("\n")
}

///|
/// Compare a candidate snapshot against several historical baselines.
fn run_compatibility_matrix(args : Array[String]) -> Result[String, String] {
  let parsed = match
    parse_compatibility_matrix_arguments(args, 3, [], BreakingOnly) {
    Ok(parsed) => parsed
    Err(error) => return Err(error)
  }
  let candidate = match read_config(args.get(2).unwrap()) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let baselines = match
    read_compatibility_baselines(parsed.baseline_paths, 0, []) {
    Ok(baselines) => baselines
    Err(error) => return Err(error)
  }
  let report = candidate.compatibility_matrix(baselines)
  let output = render_compatibility_matrix(report, parsed.policy)
  if report.passes(parsed.policy) {
    Ok(output + "\ncompatibility matrix passed")
  } else {
    let count = report.failed_count(parsed.policy)
    let noun = if count == 1 { "baseline" } else { "baselines" }
    let verb = if count == 1 { "exceeds" } else { "exceed" }
    Err(
      output +
      "\ncompatibility matrix failed: " +
      count.to_string() +
      " " +
      noun +
      " " +
      verb +
      " the '" +
      parsed.policy.to_string() +
      "' gate",
    )
  }
}
