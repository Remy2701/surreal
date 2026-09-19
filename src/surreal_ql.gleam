import gleam/dict
import gleam/float
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import json_value

pub type SurrealQL {
  String(String)
  Int(Int)
  Float(Float)
  Bool(Bool)
  Datetime(String)
  Null
  Object(List(#(String, SurrealQL)))
  Raw(String)
  Array(List(SurrealQL))
}

pub fn nullable(
  value: option.Option(a),
  to_surql: fn(a) -> SurrealQL,
) -> SurrealQL {
  case value {
    option.Some(v) -> to_surql(v)
    option.None -> Null
  }
}

pub fn array(value: List(a), to_surql: fn(a) -> SurrealQL) -> SurrealQL {
  Array(list.map(value, to_surql))
}

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

pub fn to_string(surreal_ql: SurrealQL) -> String {
  case surreal_ql {
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
        |> list.map(fn(entry) {
          let #(key, value) = entry
          key <> ": " <> to_string(value)
        })
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

pub fn to_json(surreal_ql: SurrealQL) -> json.Json {
  case surreal_ql {
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

pub fn from_json_value(value: json_value.JsonValue) -> SurrealQL {
  case value {
    json_value.Null -> Null
    json_value.String(inner) -> String(inner)
    json_value.Int(inner) -> Int(inner)
    json_value.Bool(inner) -> Bool(inner)
    json_value.Float(inner) -> Float(inner)
    json_value.Array(inner) -> Array(list.map(inner, from_json_value))
    json_value.Object(inner) ->
      Object(
        dict.map_values(inner, fn(_, value) { from_json_value(value) })
        |> dict.to_list,
      )
  }
}
