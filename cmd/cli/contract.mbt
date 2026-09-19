///|
fn parse_contract_output_format(
  args : Array[String],
) -> Result[CliOutputFormat, String] {
  if args.length() == 3 {
    Ok(Text)
  } else {
    match (args.get(3), args.get(4)) {
      (Some("--format"), Some(value)) => parse_output_format(value)
      (Some("--format"), None) => Err("missing value after --format")
      (Some(option), _) => Err("unknown contract-check option '" + option + "'")
      (_, None) => Err("missing value after --format")
      (_, _) => Err("invalid contract-check arguments")
    }
  }
}

///|
/// Resolve a snapshot path relative to the contract manifest.
fn resolve_contract_path(manifest_path : String, entry_path : String) -> String {
  let entry : @path.Path = entry_path
  if entry.is_absolute() {
    entry.to_string()
  } else {
    let manifest : @path.Path = manifest_path
    manifest.dirname().join(entry).to_string()
  }
}

///|
/// Read a candidate or baseline snapshot referenced by a contract.
fn read_contract_snapshot(
  manifest_path : String,
  role : String,
  display_path : String,
) -> Result[@configscope.ConfigValue, String] {
  let file_path = resolve_contract_path(manifest_path, display_path)
  if !@fs.path_exists(file_path) {
    return Err(
      "contract " + role + " file '" + display_path + "' does not exist",
    )
  }
  let source : Result[String, String] = Ok(@fs.read_file_to_string(file_path)) catch {
    _ => Err("cannot read contract " + role + " file '" + display_path + "'")
  }
  let source = match source {
    Ok(source) => source
    Err(error) => return Err(error)
  }
  let value : Result[@configscope.ConfigValue, String] = Ok(
    @configscope.ConfigValue::parse_json(source),
  ) catch {
    _ =>
      Err("invalid JSON in contract " + role + " file '" + display_path + "'")
  }
  match value {
    Ok(value) => Ok(value)
    Err(error) => Err(error)
  }
}

///|
/// Read all baseline snapshots referenced by a contract in manifest order.
fn read_contract_baselines(
  manifest_path : String,
  paths : Array[String],
  index : Int,
  baselines : Array[@configscope.ConfigCompatibilityBaseline],
) -> Result[Array[@configscope.ConfigCompatibilityBaseline], String] {
  if index >= paths.length() {
    Ok(baselines)
  } else {
    let display_path = paths.get(index).unwrap()
    match read_contract_snapshot(manifest_path, "baseline", display_path) {
      Ok(value) => {
        baselines.push(
          @configscope.ConfigCompatibilityBaseline::new(display_path, value),
        )
        read_contract_baselines(manifest_path, paths, index + 1, baselines)
      }
      Err(error) => Err(error)
    }
  }
}

///|
/// Check a candidate snapshot against the baselines declared by a contract.
fn run_contract_check(args : Array[String]) -> Result[String, String] {
  let manifest_path = args.get(2).unwrap()
  let format = match parse_contract_output_format(args) {
    Ok(format) => format
    Err(error) => return Err(error)
  }
  let manifest = match read_config(manifest_path) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let contract = match
    @configscope.ConfigCompatibilityContract::from_value(manifest) {
    Ok(contract) => contract
    Err(error) =>
      return Err(
        "invalid compatibility contract '" + manifest_path + "': " + error,
      )
  }
  let candidate_path = contract.candidate_path()
  let candidate = match
    read_contract_snapshot(manifest_path, "candidate", candidate_path) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let baselines = match
    read_contract_baselines(manifest_path, contract.baseline_paths(), 0, []) {
    Ok(baselines) => baselines
    Err(error) => return Err(error)
  }
  let policy = contract.policy()
  let ignored_paths = contract.ignored_paths()
  let report = candidate
    .compatibility_matrix(baselines)
    .excluding_paths(ignored_paths)
  let ignored_text = if ignored_paths.length() == 0 {
    ""
  } else {
    "ignored paths: " +
    ignored_paths.map(path => path.to_string()).join(", ") +
    "\n"
  }
  let output = match format {
    Text =>
      "contract: " +
      manifest_path +
      "\n" +
      "candidate: " +
      candidate_path +
      "\n" +
      ignored_text +
      render_compatibility_matrix(report, policy)
    Json =>
      render_json_compatibility_contract(
        manifest_path, candidate_path, ignored_paths, report, policy,
      )
  }
  if report.passes(policy) {
    match format {
      Text => Ok(output + "\ncompatibility contract passed")
      Json => Ok(output)
    }
  } else {
    match format {
      Text => {
        let count = report.failed_count(policy)
        let noun = if count == 1 { "baseline" } else { "baselines" }
        let verb = if count == 1 { "exceeds" } else { "exceed" }
        Err(
          output +
          "\ncompatibility contract failed: " +
          count.to_string() +
          " " +
          noun +
          " " +
          verb +
          " the '" +
          policy.to_string() +
          "' gate",
        )
      }
      Json => Err(output)
    }
  }
}
