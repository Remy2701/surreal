import gleam/dict
import gleam/float
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import json_value

/// The values for Surreal Query Language (SurrealQL)
pub type SurrealQL {
  String(String)
  Int(Int)
  Float(Float)
  Bool(Bool)
  Datetime(String)
  Null
  Object(List(#(String, SurrealQL)))
  /// Be careful when using this especially if its value directly comes from 
  /// the user input, as it will be included in the query as-is.
  /// This can lead to potential security risks like SQL injection if not 
  /// handled properly.
  Raw(String)
  Array(List(SurrealQL))
}

/// Transforms the given option into a SurrealQL value, if the provided [value] 
/// is [None], it will be transformed into [Null] and otherwise converted to 
/// the relevant type using [to_surql]
pub fn nullable(
  value: option.Option(a),
  to_surql: fn(a) -> SurrealQL,
) -> SurrealQL {
  value
  |> option.map(to_surql)
  |> option.unwrap(Null)
}

/// Transforms the list of values into [SurrealQL] values using the given converter.
pub fn array(value: List(a), to_surql: fn(a) -> SurrealQL) -> SurrealQL {
  Array(list.map(value, to_surql))
}

/// (Private) utility function to escape quotes from a string.
fn escape_string(str: String) -> String {
  list.map(string.to_graphemes(str), fn(c) {
    case c {
      "\"" -> "\\\""
      "\\" -> "\\\\"
      _ -> c
    }
  })
  |> string.join("")
}

fn field_to_string(value: #(String, SurrealQL)) -> String {
  let #(key, value) = value
  key <> ": " <> to_string(value)
}

/// Converts the given SurrealQL [value] into a String.
pub fn to_string(value: SurrealQL) -> String {
  case value {
    String(s) -> "\"" <> escape_string(s) <> "\""
    Int(i) -> int.to_string(i)
    Float(f) -> float.to_string(f)
    Bool(b) if b -> "true"
    Bool(_) -> "false"
    Datetime(dt) -> "d\"" <> escape_string(dt) <> "\""
    Null -> "NONE"
    Object(fields) -> {
      let field_strings =
        fields
        |> list.map(field_to_string)
        |> string.join(", ")
      "{" <> field_strings <> "}"
    }
    Raw(s) -> s
    Array(items) -> {
      let item_strings = items |> list.map(to_string) |> string.join(", ")
      "[" <> item_strings <> "]"
    }
  }
}

/// Converts the given SurrealQL [value] into a Json value
pub fn to_json(value: SurrealQL) -> json.Json {
  case value {
    String(s) -> json.string(s)
    Int(i) -> json.int(i)
    Float(f) -> json.float(f)
    Bool(b) -> json.bool(b)
    Datetime(dt) -> json.string(dt)
    Null -> json.string("NONE")
    Object(fields) -> {
      let field_pairs =
        fields
        |> list.map(fn(entry) {
          let #(key, value) = entry
          #(key, to_json(value))
        })
      json.object(field_pairs)
    }
    Raw(s) -> json.string(s)
    Array(items) -> json.array(items, to_json)
  }
}

/// Converts a given [JsonValue] into a [SurrealQL] value.
pub fn from_json_value(value: json_value.JsonValue) -> SurrealQL {
  case value {
    json_value.Null -> Null
    json_value.String(inner) -> String(inner)
    json_value.Int(inner) -> Int(inner)
    json_value.Bool(inner) -> Bool(inner)
    json_value.Float(inner) -> Float(inner)
    json_value.Array(inner) -> Array(list.map(inner, from_json_value))
    json_value.Object(inner) ->
      dict.map_values(inner, fn(_, value) { from_json_value(value) })
      |> dict.to_list
      |> Object
  }
}
