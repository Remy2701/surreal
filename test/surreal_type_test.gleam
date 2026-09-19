import gleeunit/should
import surreal_type

//-----------------------------------------------------------------------------------------------//
//                                          From String                                          //
//-----------------------------------------------------------------------------------------------//

pub fn surreal_type_string_from_string_test() {
  "string"
  |> surreal_type.from_string
  |> should.be_ok()
  |> should.equal(surreal_type.String)
}

pub fn surreal_type_int_from_string_test() {
  "int"
  |> surreal_type.from_string
  |> should.be_ok()
  |> should.equal(surreal_type.Int)
}

pub fn surreal_type_float_from_string_test() {
  "float"
  |> surreal_type.from_string
  |> should.be_ok()
  |> should.equal(surreal_type.Float)
}

pub fn surreal_type_bool_from_string_test() {
  "bool"
  |> surreal_type.from_string
  |> should.be_ok()
  |> should.equal(surreal_type.Bool)
}

pub fn surreal_type_datetime_from_string_test() {
  "datetime"
  |> surreal_type.from_string
  |> should.be_ok()
  |> should.equal(surreal_type.Datetime)
}

pub fn surreal_type_option_from_string_test() {
  "none | string"
  |> surreal_type.from_string
  |> should.be_ok()
  |> should.equal(surreal_type.Option(surreal_type.String))
}

pub fn surreal_type_none_from_string_test() {
  "none"
  |> surreal_type.from_string
  |> should.be_ok()
  |> should.equal(surreal_type.None)
}

pub fn surreal_type_object_from_string_test() {
  "object"
  |> surreal_type.from_string
  |> should.be_ok()
  |> should.equal(surreal_type.Object)
}

//-----------------------------------------------------------------------------------------------//
//                                          To String                                          //
//-----------------------------------------------------------------------------------------------//

pub fn surreal_type_string_to_string_test() {
  surreal_type.String
  |> surreal_type.to_string
  |> should.equal("string")
}

pub fn surreal_type_int_to_string_test() {
  surreal_type.Int
  |> surreal_type.to_string
  |> should.equal("int")
}

pub fn surreal_type_float_to_string_test() {
  surreal_type.Float
  |> surreal_type.to_string
  |> should.equal("float")
}

pub fn surreal_type_bool_to_string_test() {
  surreal_type.Bool
  |> surreal_type.to_string
  |> should.equal("bool")
}

pub fn surreal_type_datetime_to_string_test() {
  surreal_type.Datetime
  |> surreal_type.to_string
  |> should.equal("datetime")
}

pub fn surreal_type_identifier_to_string_test() {
  surreal_type.Identifier("TYPE")
  |> surreal_type.to_string
  |> should.equal("string")
}

pub fn surreal_type_record_to_string_test() {
  surreal_type.Record("TYPE")
  |> surreal_type.to_string
  |> should.equal("record<TYPE>")
}

pub fn surreal_type_option_to_string_test() {
  surreal_type.Option(surreal_type.String)
  |> surreal_type.to_string
  |> should.equal("option<string>")
}

pub fn surreal_type_none_to_string_test() {
  surreal_type.None
  |> surreal_type.to_string
  |> should.equal("none")
}

pub fn surreal_type_array_to_string_test() {
  surreal_type.Array(surreal_type.String)
  |> surreal_type.to_string
  |> should.equal("array<string>")
}

pub fn surreal_type_point_to_string_test() {
  surreal_type.Point
  |> surreal_type.to_string
  |> should.equal("geometry<Point>")
}

pub fn surreal_type_object_to_string_test() {
  surreal_type.Object
  |> surreal_type.to_string
  |> should.equal("object")
}
