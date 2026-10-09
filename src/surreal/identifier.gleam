import gleam/bool
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import gleam/string
import str

const identifier_max_length = 20

const type_max_length = 20

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                          Identifier                                           //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

/// A typed identifier that can be used to uniquely identify a record in a SurrealDB database. The 
/// type parameter `a` is used to associate the identifier with a specific table or record type.
/// 
/// A typed identifier has the following string representation `type:id` but the type is optional
/// and can also be represented as just `id`.
pub type Identifier(a) {
  Identifier(type_: Option(String), id: String)
}

/// Verify that the given string is a valid identifier. An identifier must be alphanumeric and
/// cannot exceed 20 characters in length. If the string is valid, it is returned as an `Ok` 
/// result, otherwise an `Error` result is returned.
/// 
/// Note: This is not standard SurrealDB behavior, but a custom validation to ensure that 
/// identifiers are valid and conform to the expected format. This is done to avoid query
/// injection and other security issues that may arise from using invalid identifiers in queries.
fn verify_identifier(str: String) -> Result(String, Nil) {
  use <- bool.guard(!str.is_alphanumeric(str), Error(Nil))
  use <- bool.guard(string.length(str) > identifier_max_length, Error(Nil))
  Ok(str)
}

/// Verify that the type of the identifier is valid. A type must be alphanumeric and cannot exceed 
/// 20 characters.
/// 
/// Note: This is not standard SurrealDB behavior, but a custom validation to ensure that 
/// identifiers are valid and conform to the expected format. This is done to avoid query
/// injection and other security issues that may arise from using invalid identifiers in queries.
fn verify_type(str: String) -> Result(String, Nil) {
  use <- bool.guard(
    !str.is_alphanumeric(string.replace(str, "_", "")),
    Error(Nil),
  )
  use <- bool.guard(string.length(str) >= type_max_length, Error(Nil))
  Ok(str)
}

/// Create a new identifier with the given type and id. The type is optional and can be used to
/// associate the identifier with a specific table or record type.
pub fn from_string(str: String) -> Result(Identifier(a), Nil) {
  case string.split_once(str, ":") {
    Ok(#(type_, id)) -> {
      use type_ <- result.try(verify_type(type_))
      use id <- result.try(verify_identifier(id))
      Ok(Identifier(Some(type_), id))
    }
    _ -> {
      use str <- result.try(verify_identifier(str))
      Ok(Identifier(None, str))
    }
  }
}

/// Convert the identifier to a string representation. If the identifier has a type, it will be
/// represented as `type:id`, otherwise it will be represented as just `id`.
pub fn to_string(self: Identifier(a)) -> String {
  case self.type_ {
    Some(type_) -> type_ <> ":" <> self.id
    None -> self.id
  }
}

/// Replace the type of the identifier with a new type. This is useful for converting between different
/// types of identifiers that may represent the same underlying record in the database.
pub fn typed(self: Identifier(a), type_: String) -> Identifier(b) {
  Identifier(Some(type_), self.id)
}

/// Remove the type from the identifier, returning an untyped identifier. This is useful for
/// converting a typed identifier to an untyped identifier that can be used in contexts where the
/// type is not needed or relevant.
pub fn untyped(self: Identifier(a)) -> Identifier(b) {
  Identifier(None, self.id)
}

/// The decoder for the Identifier type. This decoder will parse a string representation of an identifier
/// and return an Identifier value. If the string is not a valid identifier, the decoder will return an error.
pub fn decoder() -> decode.Decoder(Identifier(a)) {
  use str <- decode.then(decode.string)
  case from_string(str) {
    Ok(id) -> decode.success(id)
    Error(_) ->
      decode.failure(Identifier(None, "INVALID"), "Invalid identifier")
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
        Identifier(None, "INVALID"),
        "Identifier[" <> string.join(allowed_types, " | ") <> "]",
      )
  }
}

/// Compare two identifiers by their string representation. This is useful for sorting or ordering
/// identifiers in a consistent manner. The comparison is case-sensitive and will return an `Order`
/// value indicating whether the first identifier is less than, equal to, or greater than the second
/// identifier.
pub fn compare(a: Identifier(a), b: Identifier(b)) -> order.Order {
  string.compare(to_string(a), to_string(b))
}

/// Generate a new identifier with a random alphanumeric string of 20 characters. The type is 
/// optional and can be used to associate the identifier with a specific table or record type.
pub fn generate(type_: Option(String)) -> Identifier(a) {
  let assert [codepoint_a, codepoint_0] = string.to_utf_codepoints("a0")

  let str =
    int.range(0, identifier_max_length, "", fn(acc, _) {
      let number = int.random(36)
      let character = case number >= 26 {
        False -> {
          codepoint_a
          |> string.utf_codepoint_to_int()
          |> int.add(number)
          |> string.utf_codepoint()
          |> result.unwrap(codepoint_a)
          |> list.wrap()
          |> string.from_utf_codepoints()
        }
        True -> {
          codepoint_0
          |> string.utf_codepoint_to_int()
          |> int.add(number)
          |> int.subtract(26)
          |> string.utf_codepoint()
          |> result.unwrap(codepoint_0)
          |> list.wrap()
          |> string.from_utf_codepoints()
        }
      }
      acc <> character
    })

  Identifier(type_, str)
}
