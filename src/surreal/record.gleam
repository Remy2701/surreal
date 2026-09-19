import gleam/dynamic/decode
import gleam/json
import surreal/identifier
import surreal_ql

pub type Record(a) {
  Record(id: identifier.Identifier(a), data: a)
  Id(id: identifier.Identifier(a))
}

pub fn to_json(record: Record(a), to_json: fn(a) -> json.Json) -> json.Json {
  case record {
    Record(data:, ..) -> to_json(data)
    Id(value) -> json.string(identifier.to_string(value))
  }
}

pub fn to_surql(
  record: Record(a),
  to_surql: fn(a) -> surreal_ql.SurrealQL,
) -> surreal_ql.SurrealQL {
  case record {
    Record(data:, ..) -> to_surql(data)
    Id(value) -> surreal_ql.String(identifier.to_string(value))
  }
}

pub fn decoder(
  decoder: decode.Decoder(a),
  id: fn(a) -> identifier.Identifier(a),
) -> decode.Decoder(Record(a)) {
  decode.one_of(decoder |> decode.map(fn(data) { Record(id(data), data) }), [
    identifier.decoder() |> decode.map(Id),
  ])
}
