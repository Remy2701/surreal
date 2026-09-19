import gleam/result

pub type SurrealType {
  String
  Int
  Float
  Bool
  Datetime
  Identifier(String)
  Record(String)
  Option(SurrealType)
  Array(SurrealType)
  Point
  Object
  None
}

pub fn from_string(str: String) -> Result(SurrealType, String) {
  case str {
    "string" -> Ok(String)
    "int" -> Ok(Int)
    "float" -> Ok(Float)
    "bool" -> Ok(Bool)
    "datetime" -> Ok(Datetime)
    "none | " <> rest -> {
      use inner_type <- result.try(from_string(rest))
      Ok(Option(inner_type))
    }
    "object" -> Ok(Object)
    "none" -> Ok(None)
    _ -> Error("Unknown type: " <> str)
  }
}

pub fn to_gleam_type_str(kind: SurrealType) -> String {
  case kind {
    Datetime -> "birl.Time"
    Int -> "Int"
    Float -> "Float"
    Identifier(name) -> "identifier.Identifier(" <> name <> ")"
    Record(name) -> "record.Record(" <> name <> ")"
    String -> "String"
    Bool -> "Bool"
    Option(inner) -> "option.Option(" <> to_gleam_type_str(inner) <> ")"
    Array(inner) -> "List(" <> to_gleam_type_str(inner) <> ")"
    Point -> "point.Point"
    Object -> "json_value.JsonValue"
    None -> "Nil"
  }
}

pub fn to_string(type_: SurrealType) -> String {
  case type_ {
    String -> "string"
    Int -> "int"
    Float -> "float"
    Bool -> "bool"
    Identifier(_) -> "string"
    Record(name) -> "record<" <> name <> ">"
    Datetime -> "datetime"
    Option(inner) -> "option<" <> to_string(inner) <> ">"
    Array(inner) -> "array<" <> to_string(inner) <> ">"
    Point -> "geometry<Point>"
    Object -> "object"
    None -> "none"
  }
}
