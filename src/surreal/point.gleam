import gleam/dynamic/decode
import gleam/json
import surreal_ql

pub type Point {
  Point(latitude: Float, longitude: Float)
}

pub fn decoder() -> decode.Decoder(Point) {
  use coordinates <- decode.field("coordinates", decode.list(decode.float))

  case coordinates {
    [latitude, longitude] -> decode.success(Point(latitude, longitude))
    _ ->
      decode.failure(
        Point(0.0, 0.0),
        "Expected a list of two floats for coordinates",
      )
  }
}

pub fn to_json(self: Point) -> json.Json {
  json.object([
    #("type", json.string("Point")),
    #(
      "coordinates",
      json.preprocessed_array([
        json.float(self.latitude),
        json.float(self.longitude),
      ]),
    ),
  ])
}

pub fn to_surql(self: Point) -> surreal_ql.SurrealQL {
  surreal_ql.Object([
    #("type", surreal_ql.String("Point")),
    #(
      "coordinates",
      surreal_ql.Array([
        surreal_ql.Float(self.latitude),
        surreal_ql.Float(self.longitude),
      ]),
    ),
  ])
}
