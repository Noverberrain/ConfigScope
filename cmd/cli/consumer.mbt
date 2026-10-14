///|
/// Check a candidate against expectations explicitly declared by its consumer.
/// The report never prints candidate or allowed values.
fn run_consumer_check(args : Array[String]) -> Result[String, String] {
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
  let lines : Array[String] = []
  for issue in issues {
    lines.push("[" + issue.kind().to_string() + "] " + issue.path().to_string())
  }
  if issues.length() == 0 {
    Ok("consumer constraints passed (declared rules only)")
  } else {
    lines.push(
      "consumer constraints failed: " +
      issues.length().to_string() +
      " violation(s)",
    )
    Err(lines.join("\n"))
  }
}
