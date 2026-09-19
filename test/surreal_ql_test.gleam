import gleam/dict
import gleam/json
import gleeunit/should
import json_value
import surreal_ql

//-----------------------------------------------------------------------------------------------//
//                                            To JSON                                            //
//-----------------------------------------------------------------------------------------------//

pub fn surreal_ql_string_to_json_test() {
  "Hello world!"
  |> surreal_ql.String
  |> surreal_ql.to_json
  |> should.equal(json.string("Hello world!"))
}

pub fn surreal_ql_int_to_json_test() {
  42
  |> surreal_ql.Int
  |> surreal_ql.to_json
  |> should.equal(json.int(42))
}

pub fn surreal_ql_float_to_json_test() {
  42.0
  |> surreal_ql.Float
  |> surreal_ql.to_json
  |> should.equal(json.float(42.0))
}

pub fn surreal_ql_bool_to_json_test() {
  False
  |> surreal_ql.Bool
  |> surreal_ql.to_json
  |> should.equal(json.bool(False))
}

pub fn surreal_ql_datetime_to_json_test() {
  "2024-06-05T12:34:56Z"
  |> surreal_ql.Datetime
  |> surreal_ql.to_json
  |> should.equal(json.string("2024-06-05T12:34:56Z"))
}

pub fn surreal_ql_null_to_json_test() {
  surreal_ql.Null
  |> surreal_ql.to_json
  |> should.equal(json.string("NONE"))
}

pub fn surreal_ql_object_to_json_test() {
  surreal_ql.Object([
    #("key1", surreal_ql.String("value1")),
    #("key2", surreal_ql.Int(42)),
  ])
  |> surreal_ql.to_json
  |> should.equal(
    json.object([
      #("key1", json.string("value1")),
      #("key2", json.int(42)),
    ]),
  )
}

pub fn surreal_ql_raw_to_json_test() {
  "user:123"
  |> surreal_ql.Raw
  |> surreal_ql.to_json
  |> should.equal(json.string("user:123"))
}

pub fn surreal_ql_array_to_json_test() {
  surreal_ql.Array([
    surreal_ql.String("a"),
    surreal_ql.String("b"),
    surreal_ql.String("c"),
  ])
  |> surreal_ql.to_json
  |> should.equal(
    json.preprocessed_array([
      json.string("a"),
      json.string("b"),
      json.string("c"),
    ]),
  )
}

//-----------------------------------------------------------------------------------------------//
//                                            To String                                            //
//-----------------------------------------------------------------------------------------------//

pub fn surreal_ql_string_to_string_test() {
  "Hello world!"
  |> surreal_ql.String
  |> surreal_ql.to_string
  |> should.equal("\"Hello world!\"")
}

pub fn surreal_ql_int_to_string_test() {
  42
  |> surreal_ql.Int
  |> surreal_ql.to_string
  |> should.equal("42")
}

pub fn surreal_ql_float_to_string_test() {
  42.0
  |> surreal_ql.Float
  |> surreal_ql.to_string
  |> should.equal("42.0")
}

pub fn surreal_ql_bool_to_string_test() {
  False
  |> surreal_ql.Bool
  |> surreal_ql.to_string
  |> should.equal("false")
}

pub fn surreal_ql_datetime_to_string_test() {
  "2024-06-05T12:34:56Z"
  |> surreal_ql.Datetime
  |> surreal_ql.to_string
  |> should.equal("d\"2024-06-05T12:34:56Z\"")
}

pub fn surreal_ql_null_to_string_test() {
  surreal_ql.Null
  |> surreal_ql.to_string
  |> should.equal("NONE")
}

pub fn surreal_ql_object_to_string_test() {
  surreal_ql.Object([
    #("key1", surreal_ql.String("value1")),
    #("key2", surreal_ql.Int(42)),
  ])
  |> surreal_ql.to_string
  |> should.equal("{key1: \"value1\", key2: 42}")
}

pub fn surreal_ql_raw_to_string_test() {
  "user:123"
  |> surreal_ql.Raw
  |> surreal_ql.to_string
  |> should.equal("user:123")
}

pub fn surreal_ql_array_to_string_test() {
  surreal_ql.Array([
    surreal_ql.String("a"),
    surreal_ql.String("b"),
    surreal_ql.String("c"),
  ])
  |> surreal_ql.to_string
  |> should.equal("[\"a\", \"b\", \"c\"]")
}

//-----------------------------------------------------------------------------------------------//
//                                        From JSON Value                                        //
//-----------------------------------------------------------------------------------------------//

pub fn surreal_ql_null_from_json_test() {
  json_value.Null
  |> surreal_ql.from_json_value
  |> should.equal(surreal_ql.Null)
}

pub fn surreal_ql_string_from_json_test() {
  json_value.String("Hello world!")
  |> surreal_ql.from_json_value
  |> should.equal(surreal_ql.String("Hello world!"))
}

pub fn surreal_ql_int_from_json_test() {
  json_value.Int(42)
  |> surreal_ql.from_json_value
  |> should.equal(surreal_ql.Int(42))
}

pub fn surreal_ql_float_from_json_test() {
  json_value.Float(42.0)
  |> surreal_ql.from_json_value
  |> should.equal(surreal_ql.Float(42.0))
}

pub fn surreal_ql_bool_from_json_test() {
  json_value.Bool(False)
  |> surreal_ql.from_json_value
  |> should.equal(surreal_ql.Bool(False))
}

pub fn surreal_ql_array_from_json_test() {
  json_value.Array([
    json_value.String("a"),
    json_value.String("b"),
    json_value.String("c"),
  ])
  |> surreal_ql.from_json_value
  |> should.equal(
    surreal_ql.Array([
      surreal_ql.String("a"),
      surreal_ql.String("b"),
      surreal_ql.String("c"),
    ]),
  )
}

pub fn surreal_ql_object_from_json_test() {
  json_value.Object(
    dict.from_list([
      #("key1", json_value.String("value1")),
      #("key2", json_value.Int(42)),
    ]),
  )
  |> surreal_ql.from_json_value
  |> should.equal(
    surreal_ql.Object([
      #("key1", surreal_ql.String("value1")),
      #("key2", surreal_ql.Int(42)),
    ]),
  )
}
