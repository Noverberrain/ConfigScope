///|
/// A named configuration source used by future layered merges.
pub struct ConfigLayer {
  name : String
  value : ConfigValue
} derive(Eq, Debug)

///|
/// Create a configuration layer with a source name and value.
pub fn ConfigLayer::new(name : String, value : ConfigValue) -> ConfigLayer {
  { name, value }
}

///|
/// Return the source name associated with this layer.
pub fn ConfigLayer::name(self : ConfigLayer) -> String {
  self.name
}

///|
/// Return the configuration value stored in this layer.
pub fn ConfigLayer::value(self : ConfigLayer) -> ConfigValue {
  self.value
}
