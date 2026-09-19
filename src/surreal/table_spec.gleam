import gleam/dynamic/decode
import gleam/json
import surreal/identifier
import surreal/node
import surreal_ql

pub type TableSpec(a) {
  TableSpec(
    table_name: String,
    query_string: String,
    query: List(node.Node),
    id: fn(a) -> identifier.Identifier(a),
    to_surql: fn(a) -> surreal_ql.SurrealQL,
    to_json: fn(a) -> json.Json,
    decoder: fn() -> decode.Decoder(a),
  )
}
