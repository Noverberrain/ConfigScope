///|
/// An ordered collection of named configuration layers.
///
/// Layers are merged from first to last, so later layers have higher
/// precedence.
pub struct LayeredConfig {
  layers : Array[ConfigLayer]
} derive(Eq, Debug)

///|
/// Create an ordered configuration from the supplied layers.
///
/// The input array is copied, so later changes to the caller's array do not
/// change the layer ordering stored by this value.
pub fn LayeredConfig::new(layers : Array[ConfigLayer]) -> LayeredConfig {
  { layers: layers.copy() }
}

///|
/// Return an empty ordered configuration.
pub fn LayeredConfig::empty() -> LayeredConfig {
  { layers: [] }
}

///|
/// Return the number of layers in this configuration.
pub fn LayeredConfig::length(self : LayeredConfig) -> Int {
  self.layers.length()
}

///|
/// Return one layer by position, or `None` when the index is out of bounds.
pub fn LayeredConfig::layer(self : LayeredConfig, index : Int) -> ConfigLayer? {
  self.layers.get(index)
}

///|
/// Merge all layers from first to last and report structural conflicts.
///
/// An empty configuration has no value to merge and returns `None`.
pub fn LayeredConfig::merge_with_report(self : LayeredConfig) -> MergeResult? {
  let first = self.layers.get(0)
  match first {
    None => None
    Some(first_layer) => {
      let mut value = first_layer.value()
      let conflicts : Array[ConfigConflict] = []
      let mut index = 1
      while index < self.layers.length() {
        let layer = self.layers.get(index).unwrap()
        let result = value.deep_merge_with_report(layer.value())
        value = result.value()
        result.conflicts.each(conflict => conflicts.push(conflict))
        index = index + 1
      }
      Some({ value, conflicts })
    }
  }
}

///|
/// Merge all layers from first to last, or return `None` for no layers.
pub fn LayeredConfig::merge(self : LayeredConfig) -> ConfigValue? {
  match self.merge_with_report() {
    None => None
    Some(result) => Some(result.value())
  }
}
