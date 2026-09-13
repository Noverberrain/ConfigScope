///|
/// Keep the explicit legacy package available to migration tests without
/// re-exporting its types from the primary ConfigScope facade.
fn legacy_layer_name(layer : @legacy.ConfigLayer) -> String {
  layer.name()
}

///|
let _legacy_layer_name : (@legacy.ConfigLayer) -> String = legacy_layer_name
