///|
fn render_consumer_issues(
  issues : Array[@configscope.ConfigConsumerIssue],
) -> String {
  let lines : Array[String] = []
  for issue in issues {
    lines.push("[" + issue.kind().to_string() + "] " + issue.path().to_string())
  }
  if issues.length() == 0 {
    "consumer constraints passed (declared rules only)"
  } else {
    lines.push(
      "consumer constraints failed: " +
      issues.length().to_string() +
      " violation(s)",
    )
    lines.join("\n")
  }
}

///|
/// Check a candidate against explicitly declared consumer expectations.
fn run_consumer_check(args : Array[String]) -> Result[String, String] {
  let format = if args.length() == 4 {
    Text
  } else {
    if args.get(4) != Some("--format") {
      return Err("expected --format text|json after consumer paths")
    }
    match parse_output_format(args.get(5).unwrap()) {
      Ok(format) => format
      Err(error) => return Err(error)
    }
  }
  let candidate = match read_config(args.get(2).unwrap()) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let source = match read_config(args.get(3).unwrap()) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let contract = match @configscope.ConfigConsumerContract::from_value(source) {
    Ok(contract) => contract
    Err(error) => return Err("invalid consumer contract: " + error)
  }
  let issues = contract.check(candidate)
  let output = match format {
    Text => render_consumer_issues(issues)
    Json =>
      render_json_consumer(args.get(2).unwrap(), args.get(3).unwrap(), issues)
  }
  if issues.length() == 0 {
    Ok(output)
  } else {
    Err(output)
  }
}

///|
priv struct ConsumerGateEntry {
  name : String
  issues : Array[@configscope.ConfigConsumerIssue]
}

///|
fn check_contract_consumers(
  manifest : String,
  paths : Array[String],
  candidate : @configscope.ConfigValue,
) -> Result[Array[ConsumerGateEntry], String] {
  let entries : Array[ConsumerGateEntry] = []
  for path in paths {
    let source = match read_contract_snapshot(manifest, "consumer", path) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let contract = match
      @configscope.ConfigConsumerContract::from_value(source) {
      Ok(contract) => contract
      Err(error) =>
        return Err("invalid consumer contract '" + path + "': " + error)
    }
    entries.push({ name: path, issues: contract.check(candidate), })
  }
  Ok(entries)
}
