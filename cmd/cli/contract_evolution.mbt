///|
fn evolution_impact_label(
  impact : @configscope.ConfigContractEvolutionImpact,
) -> String {
  match impact {
    Equivalent => "equivalent"
    Tightened => "tightened"
    Relaxed => "relaxed"
    Incomparable => "incomparable"
    Unknown => "unknown"
  }
}

///|
fn read_evolution_contract(
  path : String,
  role : String,
) -> Result[@configscope.ConfigConsumerContract, String] {
  let value = match read_config(path) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match @configscope.ConfigConsumerContract::from_value(value) {
    Ok(contract) => Ok(contract)
    Err(_) =>
      Err("invalid " + role + " consumer contract: " + release_label(path))
  }
}

///|
fn render_contract_evolution(
  before : String,
  after : String,
  changes : Array[@configscope.ConfigContractEvolutionChange],
  format : CliOutputFormat,
) -> String {
  match format {
    Text => {
      let lines = [
        "before contract: " + release_label(before),
        "after contract: " + release_label(after),
        "scope: per declared path; not a release gate",
      ]
      for change in changes {
        lines.push(
          "[" +
          evolution_impact_label(change.impact()) +
          "] " +
          release_label(change.path().to_string()) +
          " reason=" +
          change.reason(),
        )
      }
      lines.push("changed rule paths: " + changes.length().to_string())
      lines.push("analysis: completed; unknown is not proof of compatibility")
      lines.join("\n")
    }
    Json => {
      let summary = Map([("total", json_int(changes.length()))])
      for
        label in [
          "equivalent", "tightened", "relaxed", "incomparable", "unknown",
        ] {
        summary[label] = json_int(
          changes
          .filter(change => evolution_impact_label(change.impact()) == label)
          .length(),
        )
      }
      Json::object(
        Map([
          ("kind", json_string("contract_evolution_report")),
          ("schema_version", json_int(1)),
          ("scope", json_string("per_declared_path")),
          ("before_contract", json_string(before)),
          ("after_contract", json_string(after)),
          ("analysis_completed", Json::boolean(true)),
          ("is_release_gate", Json::boolean(false)),
          ("summary", Json::object(summary)),
          (
            "changes",
            Json::array(
              changes.map(change => {
                Json::object(
                  Map([
                    ("path", json_string(change.path().to_string())),
                    (
                      "impact",
                      json_string(evolution_impact_label(change.impact())),
                    ),
                    ("reason", json_string(change.reason())),
                  ]),
                )
              }),
            ),
          ),
        ]),
      ).stringify()
    }
  }
}

///|
/// Diagnostic only: successful analysis exits zero for ALL classifications,
/// including Unknown and Tightened. No aggregate compatibility claim is made.
fn run_contract_evolution(args : Array[String]) -> Result[String, String] {
  let format = if args.length() == 4 {
    Text
  } else {
    match parse_output_format(args[5]) {
      Ok(format) => format
      Err(error) => return Err(error)
    }
  }
  let before = match read_evolution_contract(args[2], "before") {
    Ok(contract) => contract
    Err(error) => return Err(error)
  }
  let after = match read_evolution_contract(args[3], "after") {
    Ok(contract) => contract
    Err(error) => return Err(error)
  }
  Ok(
    render_contract_evolution(
      args[2],
      args[3],
      before.evolution_to(after),
      format,
    ),
  )
}
