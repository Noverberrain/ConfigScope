///|
/// Command-line arguments for creating a compatibility contract.
priv struct ContractInitArguments {
  candidate_path : String
  baseline_paths : Array[String]
  policy : @configscope.ConfigCompatibilityPolicy
  output_path : String
  ignored_paths : Array[String]
}

///|
/// Validate one exact path or trailing `.*` subtree pattern.
fn validate_contract_init_ignore_path(
  source : String,
) -> Result[String, String] {
  let path = match @configscope.parse_path(source) {
    Ok(path) => path
    Err(error) =>
      return Err("invalid --ignore-path '" + source + "': " + error.to_string())
  }
  for index in 0..<path.length() {
    if path.segment(index) == Some("*") &&
      (index == 0 || index != path.length() - 1) {
      return Err(
        "invalid --ignore-path '" +
        source +
        "': '*' must be the final segment after a path prefix",
      )
    }
  }
  Ok(path.to_string())
}

///|
/// Parse the inputs and options for `contract-init`.
fn parse_contract_init_arguments(
  args : Array[String],
  index : Int,
  candidate_path : String,
  baseline_paths : Array[String],
  seen_baselines : Map[String, Bool],
  policy : @configscope.ConfigCompatibilityPolicy,
  output_path : String,
  ignored_paths : Array[String],
  seen_ignored : Map[String, Bool],
) -> Result[ContractInitArguments, String] {
  if index >= args.length() {
    if baseline_paths.length() == 0 {
      Err("contract-init requires at least one baseline file")
    } else {
      Ok({ candidate_path, baseline_paths, policy, output_path, ignored_paths })
    }
  } else {
    match args.get(index) {
      Some("--fail-on") =>
        match args.get(index + 1) {
          Some(value) =>
            match parse_compatibility_policy(value) {
              Ok(next_policy) =>
                parse_contract_init_arguments(
                  args,
                  index + 2,
                  candidate_path,
                  baseline_paths,
                  seen_baselines,
                  next_policy,
                  output_path,
                  ignored_paths,
                  seen_ignored,
                )
              Err(error) => Err(error)
            }
          None => Err("missing value after --fail-on")
        }
      Some("--output") =>
        match args.get(index + 1) {
          Some(value) =>
            if value == "" {
              Err("contract-init output path must be non-empty")
            } else {
              parse_contract_init_arguments(
                args,
                index + 2,
                candidate_path,
                baseline_paths,
                seen_baselines,
                policy,
                value,
                ignored_paths,
                seen_ignored,
              )
            }
          None => Err("missing value after --output")
        }
      Some("--ignore-path") =>
        match args.get(index + 1) {
          Some(value) =>
            if value.has_prefix("--") {
              Err("missing value after --ignore-path")
            } else {
              match validate_contract_init_ignore_path(value) {
                Ok(path) =>
                  if seen_ignored.contains(path) {
                    Err(
                      "contract-init received duplicate ignore path '" +
                      path +
                      "'",
                    )
                  } else {
                    seen_ignored[path] = true
                    ignored_paths.push(path)
                    parse_contract_init_arguments(
                      args,
                      index + 2,
                      candidate_path,
                      baseline_paths,
                      seen_baselines,
                      policy,
                      output_path,
                      ignored_paths,
                      seen_ignored,
                    )
                  }
                Err(error) => Err(error)
              }
            }
          None => Err("missing value after --ignore-path")
        }
      Some(path) =>
        if path.has_prefix("--") {
          Err("unknown contract-init option '" + path + "'")
        } else if seen_baselines.contains(path) {
          Err("contract-init received duplicate baseline '" + path + "'")
        } else {
          seen_baselines[path] = true
          baseline_paths.push(path)
          parse_contract_init_arguments(
            args,
            index + 1,
            candidate_path,
            baseline_paths,
            seen_baselines,
            policy,
            output_path,
            ignored_paths,
            seen_ignored,
          )
        }
      None => Err("invalid contract-init arguments")
    }
  }
}

///|
/// Validate all snapshots before creating a contract file.
fn validate_contract_init_baselines(
  paths : Array[String],
  index : Int,
) -> Result[Unit, String] {
  if index >= paths.length() {
    Ok(())
  } else {
    let path = paths.get(index).unwrap()
    match read_config(path) {
      Ok(_) => validate_contract_init_baselines(paths, index + 1)
      Err(error) => Err(error)
    }
  }
}

///|
/// Convert a snapshot path into a portable path relative to the contract.
fn contract_init_entry_path(
  manifest_path : String,
  snapshot_path : String,
) -> String {
  let manifest : @path.Path = manifest_path
  let snapshot : @path.Path = snapshot_path
  snapshot
  .resolve()
  .relative(base=manifest.resolve().dirname())
  .to_string()
  .replace_all(old="\\", new="/")
}

///|
/// Render a deterministic compatibility contract manifest.
fn render_contract_init_manifest(
  manifest_path : String,
  candidate_path : String,
  baseline_paths : Array[String],
  policy : @configscope.ConfigCompatibilityPolicy,
  ignored_paths : Array[String],
) -> String {
  let fields : Map[String, Json] = Map([
    (
      "candidate",
      Json::string(contract_init_entry_path(manifest_path, candidate_path)),
    ),
    (
      "baselines",
      Json::array(
        baseline_paths.map(path => {
          Json::string(contract_init_entry_path(manifest_path, path))
        }),
      ),
    ),
    ("fail_on", Json::string(policy.to_string())),
  ])
  if ignored_paths.length() > 0 {
    fields["ignore_paths"] = Json::array(
      ignored_paths.map(path => Json::string(path)),
    )
  }
  let manifest = Json::object(fields)
  manifest.stringify(indent=2) + "\n"
}

///|
/// Create a compatibility contract file from existing JSON snapshots.
fn run_contract_init(args : Array[String]) -> Result[String, String] {
  let candidate_path = args.get(2).unwrap()
  if candidate_path == "" {
    return Err("contract-init candidate path must be non-empty")
  }
  let parsed = match
    parse_contract_init_arguments(
      args,
      3,
      candidate_path,
      [],
      Map([]),
      BreakingOnly,
      "configscope.contract.json",
      [],
      Map([]),
    ) {
    Ok(parsed) => parsed
    Err(error) => return Err(error)
  }
  if @fs.path_exists(parsed.output_path) {
    return Err(
      "contract output file '" +
      parsed.output_path +
      "' already exists; choose another path",
    )
  }
  match read_config(parsed.candidate_path) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  match validate_contract_init_baselines(parsed.baseline_paths, 0) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let manifest = render_contract_init_manifest(
    parsed.output_path,
    parsed.candidate_path,
    parsed.baseline_paths,
    parsed.policy,
    parsed.ignored_paths,
  )
  let write_result : Result[Unit, String] = Ok(
    @fs.write_string_to_file(parsed.output_path, manifest),
  ) catch {
    _ => Err("cannot write contract file '" + parsed.output_path + "'")
  }
  let ignored_summary = if parsed.ignored_paths.length() == 0 {
    ""
  } else {
    "\nignored paths: " + parsed.ignored_paths.length().to_string()
  }
  match write_result {
    Ok(_) =>
      Ok(
        "contract initialized: " +
        parsed.output_path +
        "\ncandidate: " +
        contract_init_entry_path(parsed.output_path, parsed.candidate_path) +
        "\nbaselines: " +
        parsed.baseline_paths.length().to_string() +
        "\ngate: " +
        parsed.policy.to_string() +
        ignored_summary,
      )
    Err(error) => Err(error)
  }
}
