import gleam/option
import gleam/result
import module
import module/id_case

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

pub fn to_gleam_type(kind: SurrealType) -> module.Module {
  case kind {
    Datetime ->
      module.binop.access(
        module.identifier.create("timestamp"),
        module.identifier.create("Timestamp"),
      )
      |> module.add_import(["gleam", "time", "timestamp"])
    Int -> module.types.int()
    Float -> module.types.float()
    Identifier(name) ->
      module.binop.access(
        module.identifier.create("identifier"),
        module.identifier.create("Identifier"),
      )
      |> module.function_call.create()
      |> module.function_call.add(module.identifier.create(name))
      |> module.add_import(["surreal", "identifier"])
    Record(name) ->
      module.binop.access(
        module.identifier.create("record"),
        module.identifier.create("Record"),
      )
      |> module.function_call.create()
      |> module.function_call.add(module.identifier.create(name))
      |> module.add_import(["surreal", "record"])
    String -> module.types.string()
    Bool -> module.identifier.create("Bool")
    Option(inner) ->
      module.binop.access(
        module.identifier.create("option"),
        module.identifier.create("Option"),
      )
      |> module.function_call.create()
      |> module.function_call.add(to_gleam_type(inner))
      |> module.add_import(["gleam", "option"])
    Array(inner) ->
      module.identifier.create("List")
      |> module.function_call.create()
      |> module.function_call.add(to_gleam_type(inner))
    Point ->
      module.binop.access(
        module.identifier.create("point"),
        module.identifier.create("Point"),
      )
      |> module.add_import(["surreal", "point"])
    Object ->
      module.binop.access(
        module.identifier.create("json_value"),
        module.identifier.create("JsonValue"),
      )
      |> module.add_import(["json_value"])
    None -> module.identifier.create("Nil")
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

pub fn to_gleam_module(
  type_: SurrealType,
  linked_enum: option.Option(String),
) -> module.Module {
  case type_ {
    Datetime ->
      module.binop.access(
        module.identifier.create("timestamp"),
        module.identifier.create("Timestamp"),
      )
      |> module.add_import(["gleam", "time", "timestamp"])
    Int -> module.identifier.create("Int")
    Float -> module.identifier.create("Float")
    Identifier(inner) ->
      module.function_call.create(module.binop.access(
        module.identifier.create("identifier"),
        module.identifier.create("Identifier"),
      ))
      |> module.function_call.add(module.identifier.create(inner))
      |> module.add_import(["surreal", "identifier"])
    Record(inner) ->
      module.function_call.create(module.binop.access(
        module.identifier.create("record"),
        module.identifier.create("Record"),
      ))
      |> module.function_call.add(module.identifier.create(inner))
      |> module.add_import(["surreal", "record"])
    String ->
      case linked_enum {
        option.Some(enum) -> module.identifier.create(enum)
        option.None -> module.identifier.create("String")
      }
    Bool -> module.identifier.create("Bool")
    Option(inner) ->
      module.function_call.create(module.binop.access(
        module.identifier.create("option"),
        module.identifier.create("Option"),
      ))
      |> module.function_call.add(to_gleam_module(inner, linked_enum))
      |> module.add_import(["surreal", "identifier"])
      |> module.add_import(["gleam", "option"])
    Array(inner) ->
      module.function_call.create(module.identifier.create("List"))
      |> module.function_call.add(to_gleam_module(inner, linked_enum))
    Point ->
      module.binop.access(
        module.identifier.create("point"),
        module.identifier.create("Point"),
      )
      |> module.add_import(["surreal", "point"])
    None -> module.identifier.create("Nil")
    Object ->
      module.binop.access(
        module.identifier.create("surreal_ql"),
        module.identifier.create("SurrealQL"),
      )
      |> module.add_import(["surreal_ql"])
  }
}

pub fn value_to_gleam_module(
  type_: SurrealType,
  linked_enum: option.Option(String),
  name: String,
) {
  case type_ {
    Datetime ->
      module.function_call.create(module.binop.access(
        module.identifier.create("surreal_ql"),
        module.identifier.create("Datetime"),
      ))
      |> module.function_call.add(
        module.function_call.create(module.binop.access(
          module.identifier.create("timestamp"),
          module.identifier.create("to_rfc3339"),
        ))
        |> module.function_call.add(module.identifier.create(name))
        |> module.function_call.add(module.binop.access(
          module.identifier.create("calendar"),
          module.identifier.create("utc_offset"),
        )),
      )
      |> module.add_import(["gleam", "time", "timestamp"])
      |> module.add_import(["gleam", "time", "calendar"])
      |> module.add_import(["surreal_ql"])
    Int ->
      module.function_call.create(module.binop.access(
        module.identifier.create("surreal_ql"),
        module.identifier.create("Int"),
      ))
      |> module.function_call.add(module.identifier.create(name))
      |> module.add_import(["surreal_ql"])
    Float ->
      module.function_call.create(module.binop.access(
        module.identifier.create("surreal_ql"),
        module.identifier.create("Float"),
      ))
      |> module.function_call.add(module.identifier.create(name))
      |> module.add_import(["surreal_ql"])
    Identifier(_) ->
      module.function_call.create(module.binop.access(
        module.identifier.create("surreal_ql"),
        module.identifier.create("Raw"),
      ))
      |> module.function_call.add(
        module.function_call.create(module.binop.access(
          module.identifier.create("identifier"),
          module.identifier.create("to_string"),
        ))
        |> module.function_call.add(module.identifier.create(name)),
      )
      |> module.add_import(["surreal_ql"])
      |> module.add_import(["surreal", "identifier"])
    Record(_) ->
      module.function_call.create(module.binop.access(
        module.identifier.create("surreal_ql"),
        module.identifier.create("Raw"),
      ))
      |> module.function_call.add(
        module.function_call.create(module.binop.access(
          module.identifier.create("identifier"),
          module.identifier.create("to_string"),
        ))
        |> module.function_call.add(module.binop.access(
          module.identifier.create(name),
          module.identifier.create("id"),
        )),
      )
      |> module.add_import(["surreal_ql"])
      |> module.add_import(["surreal", "identifier"])
    String ->
      case linked_enum {
        option.Some(enum) ->
          module.function_call.create(module.binop.access(
            module.identifier.create("surreal_ql"),
            module.identifier.create("String"),
          ))
          |> module.function_call.add(
            module.function_call.create(module.binop.access(
              module.identifier.create(id_case.namespace_only(enum)),
              module.identifier.create(
                id_case.string_to_snake_case(id_case.without_namespace(enum))
                <> "_to_string",
              ),
            ))
            |> module.function_call.add(module.identifier.create(name)),
          )
          |> module.add_import(["surreal_ql"])
        option.None ->
          module.function_call.create(module.binop.access(
            module.identifier.create("surreal_ql"),
            module.identifier.create("String"),
          ))
          |> module.function_call.add(module.identifier.create(name))
          |> module.add_import(["surreal_ql"])
      }
    Bool ->
      module.function_call.create(module.binop.access(
        module.identifier.create("surreal_ql"),
        module.identifier.create("Bool"),
      ))
      |> module.function_call.add(module.identifier.create(name))
      |> module.add_import(["surreal_ql"])
    Option(inner) ->
      module.function_call.create(module.binop.access(
        module.identifier.create("surreal_ql"),
        module.identifier.create("nullable"),
      ))
      |> module.function_call.add(module.identifier.create(name))
      |> module.function_call.add(
        module.function_definition.create()
        |> module.function_definition.add_untyped_parameter("value")
        |> module.function_definition.add(value_to_gleam_module(
          inner,
          linked_enum,
          "value",
        )),
      )
      |> module.add_import(["surreal_ql"])
    Array(inner) ->
      module.function_call.create(module.binop.access(
        module.identifier.create("surreal_ql"),
        module.identifier.create("array"),
      ))
      |> module.function_call.add(module.identifier.create(name))
      |> module.function_call.add(
        module.function_definition.create()
        |> module.function_definition.add_untyped_parameter("value")
        |> module.function_definition.add(value_to_gleam_module(
          inner,
          linked_enum,
          "value",
        )),
      )
      |> module.add_import(["surreal_ql"])
    Point ->
      module.function_call.create(module.binop.access(
        module.identifier.create("point"),
        module.identifier.create("to_surql"),
      ))
      |> module.function_call.add(module.identifier.create(name))
      |> module.add_import(["surreal", "point"])
    Object -> module.identifier.create(name)
    None ->
      module.binop.access(
        module.identifier.create("surreal_ql"),
        module.identifier.create("None"),
      )
      |> module.add_import(["surreal_ql"])
  }
}
