import gleam/dynamic/decode
import gleam/json
import surreal/identifier
import surreal/surreal_ql

/// A record in SurrealDB can either be a full record with data, or just an identifier.
/// The `id` field in the Record variant is used to allow `record.id` without matching
/// on the record.
pub type Record(a) {
  Record(id: identifier.Identifier(a), data: a)
  Id(id: identifier.Identifier(a))
}

/// Convert a record to JSON. If the record is a full record, it will be converted to JSON using 
/// the provided `to_json` function. If the record is just an identifier, it will be converted to 
/// a JSON string containing the identifier.
pub fn to_json(record: Record(a), to_json: fn(a) -> json.Json) -> json.Json {
  case record {
    Record(data:, ..) -> to_json(data)
    Id(value) -> json.string(identifier.to_string(value))
  }
}

/// Convert a record to SurrealQL. If the record is a full record, it will be converted to 
/// SurrealQL using the provided `to_surql` function. If the record is just an identifier, it will
/// be converted to a SurrealQL string containing the identifier.
pub fn to_surql(
  record: Record(a),
  to_surql: fn(a) -> surreal_ql.SurrealQL,
) -> surreal_ql.SurrealQL {
  case record {
    Record(data:, ..) -> to_surql(data)
    Id(value) -> surreal_ql.String(identifier.to_string(value))
  }
}

/// The decoder for a record. It will first attempt to decode a full record using the provided 
/// `decoder`. If that fails, it will attempt to decode just an identifier.
pub fn decoder(
  decoder: decode.Decoder(a),
  id: fn(a) -> identifier.Identifier(a),
) -> decode.Decoder(Record(a)) {
  decode.one_of(decoder |> decode.map(fn(data) { Record(id(data), data) }), [
    identifier.decoder() |> decode.map(Id),
  ])
}

/// A decoder for a record that is expected to have a specific type. It will first attempt to 
/// decode a full record using the provided `decoder`. If that fails, it will attempt to decode 
/// just an identifier with one of the specified types.
pub fn typed_decoder(
  decoder: decode.Decoder(a),
  id: fn(a) -> identifier.Identifier(a),
  types: List(String),
) -> decode.Decoder(Record(a)) {
  decode.one_of(decoder |> decode.map(fn(data) { Record(id(data), data) }), [
    identifier.typed_decoder(types) |> decode.map(Id),
  ])
}
