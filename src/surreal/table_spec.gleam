import gleam/dynamic/decode
import gleam/json
import surreal/identifier
import surreal/node
import surreal_ql

/// The table specifications for a given database table. This is a blueprint 
/// to work with both gleam's decoder and custom decoder (e.g. backstage)
pub type TableSpec(a, decoder) {
  TableSpec(
    table_name: String,
    query_string: String,
    query: List(node.Node),
    id: fn(a) -> identifier.Identifier(a),
    to_surql: fn(a) -> surreal_ql.SurrealQL,
    to_json: fn(a) -> json.Json,
    decoder: fn() -> decoder,
  )
}

/// The table specifications for a given database table using Gleam's decoder.
pub type GleamTableSpec(a) =
  TableSpec(a, decode.Decoder(a))
