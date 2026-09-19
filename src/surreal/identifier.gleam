import gleam/bool
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option
import gleam/order
import gleam/result
import gleam/string
import str

//-----------------------------------------------------------------------------------------------//
//                                          Identifier                                           //
//-----------------------------------------------------------------------------------------------//

/// A typed identifier that can be used to uniquely identify a record in a SurrealDB database. The 
/// type parameter `a` is used to associate the identifier with a specific table or record type.
/// 
/// A typed identifier has the following string representation `type:id` but the type is optional
/// and can also be represented as just `id`.
pub type Identifier(a) {
  Identifier(type_: option.Option(String), id: String)
}

fn verify_identifier(str: String) -> Result(String, Nil) {
  use <- bool.guard(!str.is_alphanumeric(str), Error(Nil))
  use <- bool.guard(string.length(str) > 20, Error(Nil))
  Ok(str)
}

fn verify_type(str: String) -> Result(String, Nil) {
  use <- bool.guard(
    !str.is_alphanumeric(string.replace(str, "_", "")),
    Error(Nil),
  )
  use <- bool.guard(string.length(str) >= 20, Error(Nil))
  Ok(str)
}

/// Create a new identifier with the given type and id. The type is optional and can be used to
/// associate the identifier with a specific table or record type.
pub fn from_string(str: String) -> Result(Identifier(a), Nil) {
  case string.split_once(str, ":") {
    Ok(#(type_, id)) -> {
      use type_ <- result.try(verify_type(type_))
      use id <- result.try(verify_identifier(id))
      Ok(Identifier(option.Some(type_), id))
    }
    _ -> {
      use str <- result.try(verify_identifier(str))
      Ok(Identifier(option.None, str))
    }
  }
}

/// Convert the identifier to a string representation. If the identifier has a type, it will be
/// represented as `type:id`, otherwise it will be represented as just `id`.
pub fn to_string(self: Identifier(a)) -> String {
  case self.type_ {
    option.Some(type_) -> type_ <> ":" <> self.id
    option.None -> self.id
  }
}

/// Replace the type of the identifier with a new type. This is useful for converting between different
/// types of identifiers that may represent the same underlying record in the database.
pub fn typed(self: Identifier(a), type_: String) -> Identifier(b) {
  Identifier(option.Some(type_), self.id)
}

/// Remove the type from the identifier, returning an untyped identifier. This is useful for
/// converting a typed identifier to an untyped identifier that can be used in contexts where the
/// type is not needed or relevant.
pub fn untyped(self: Identifier(a)) -> Identifier(b) {
  Identifier(option.None, self.id)
}

/// The decoder for the Identifier type. This decoder will parse a string representation of an identifier
/// and return an Identifier value. If the string is not a valid identifier, the decoder will return an error.
pub fn decoder() -> decode.Decoder(Identifier(a)) {
  use str <- decode.then(decode.string)
  case from_string(str) {
    Ok(id) -> decode.success(id)
    Error(_) ->
      decode.failure(Identifier(option.None, "INVALID"), "Invalid identifier")
  }
}

/// The decoder for the Identifier type. This decoder will parse a string representation of an identifier
/// and return an Identifier value. If the string is not a valid identifier, the decoder will return an error.
pub fn typed_decoder(
  allowed_types: List(String),
) -> decode.Decoder(Identifier(a)) {
  use id <- decode.then(decoder())

  let allowed =
    option.map(id.type_, list.contains(allowed_types, _))
    |> option.unwrap(True)

  case allowed {
    True ->
      decode.success(case allowed_types {
        [first, ..] -> typed(id, first)
        _ -> id
      })
    False ->
      decode.failure(
        Identifier(option.None, "INVALID"),
        "Identifier[" <> string.join(allowed_types, " | ") <> "]",
      )
  }
}

pub fn compare(a: Identifier(a), b: Identifier(b)) -> order.Order {
  string.compare(to_string(a), to_string(b))
}

pub fn generate(type_: option.Option(String)) -> Identifier(a) {
  let assert [codepoint_a, codepoint_0] = string.to_utf_codepoints("a0")

  let str =
    int.range(0, 20, "", fn(acc, _) {
      let i = int.random(36)
      acc
      <> case int.compare(i, 26) {
        order.Lt -> {
          let assert Ok(codepoint) =
            string.utf_codepoint(string.utf_codepoint_to_int(codepoint_a) + i)
          string.from_utf_codepoints([codepoint])
        }
        _ -> {
          let assert Ok(codepoint) =
            string.utf_codepoint(
              string.utf_codepoint_to_int(codepoint_0) + i - 26,
            )
          string.from_utf_codepoints([codepoint])
        }
      }
    })

  Identifier(type_, str)
}
