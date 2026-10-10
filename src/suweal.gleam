import gleam/bit_array
import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/json
import gleam/option
import gleam/result
import gleam/string

//-----------------------------------------------------------------------------------------------//
//                                          Connection                                           //
//-----------------------------------------------------------------------------------------------//

/// A connection to a SurrealDB instance.
pub type Connection {
  Connection(
    endpoint: String,
    namespace: String,
    database: String,
    authorization: String,
  )
}

/// Generates a Basic authorization header value from a username and password. The username and 
/// password are concatenated with a colon and then base64 encoded.
fn generate_basic_authorization(username: String, password: String) -> String {
  bit_array.from_string(username <> ":" <> password)
  |> bit_array.base64_encode(True)
  |> string.append("Basic ", _)
}

/// Create a new connection to a SurrealDB instance with the given endpoint, namespace, database, 
/// username and password. The username and password will be used to generate a Basic 
/// Authorization header for the connection.
pub fn connection(
  endpoint endpoint: String,
  namespace namespace: String,
  database database: String,
  username username: String,
  password password: String,
) -> Connection {
  Connection(
    endpoint,
    namespace,
    database,
    authorization: generate_basic_authorization(username, password),
  )
}

/// Replace the namespace of a connection with a new namespace. This is useful for switching 
/// between different namespaces in the same SurrealDB instance.
pub fn with_namespace(connection: Connection, namespace: String) -> Connection {
  Connection(..connection, namespace:)
}

/// Replace the database of a connection with a new database. This is useful for switching
/// between different databases in the same SurrealDB instance.
pub fn with_database(connection: Connection, database: String) -> Connection {
  Connection(..connection, database:)
}

/// The error type for decoding the Basic authorization header of a connection.
pub type DecodeCredentialsError {
  InvalidBase64
  InvalidFormat
}

/// Decode the Basic authorization header of a connection into a tuple of username and password.
pub fn decode_credentials(
  connection: Connection,
) -> Result(#(String, String), DecodeCredentialsError) {
  use bytes <- result.try(
    connection.authorization
    |> string.remove_prefix("Basic ")
    |> bit_array.base64_decode()
    |> result.replace_error(InvalidBase64),
  )

  use creds <- result.try(
    bit_array.to_string(bytes)
    |> result.replace_error(InvalidFormat),
  )

  case string.split(creds, ":") {
    [username, password] -> Ok(#(username, password))
    _ -> Error(InvalidFormat)
  }
}

//-----------------------------------------------------------------------------------------------//
//                                           Response                                            //
//-----------------------------------------------------------------------------------------------//

pub type SurrealResponse(a) {
  SurrealResponse(
    time: String,
    type_: option.Option(String),
    result: option.Option(a),
  )
  SurrealErrorResponse(
    kind: String,
    type_: option.Option(String),
    time: String,
    details: decode.Dynamic,
    result: String,
  )
}

pub fn should_be_success(response: SurrealResponse(a)) -> option.Option(a) {
  case response {
    SurrealResponse(result:, ..) -> result
    SurrealErrorResponse(..) ->
      panic as "Expected a successful response, but got an error response."
  }
}

pub fn should_be_error(response: SurrealResponse(a)) -> Nil {
  case response {
    SurrealErrorResponse(..) -> Nil
    SurrealResponse(..) ->
      panic as "Expected an error response, but got a successful response."
  }
}

pub fn expect_single_result(
  response: Result(List(SurrealResponse(List(a))), SurrealError),
  msg: String,
) -> a {
  let assert Ok([SurrealResponse(result: option.Some([result]), ..)]) = response
    as msg
  result
}

pub fn result_decoder(
  decoder: decode.Decoder(a),
) -> decode.Decoder(Result(List(SurrealResponse(a)), SurrealError)) {
  decode.one_of(decode.map(decode.list(surreal_response_decoder(decoder)), Ok), [
    decode.map(surreal_error_decoder(), Error),
  ])
}

pub fn auth_result_decoder() -> decode.Decoder(Result(String, SurrealError)) {
  decode.one_of(
    {
      use token <- decode.field("token", decode.string)
      decode.success(Ok(token))
    },
    [
      decode.map(surreal_error_decoder(), Error),
    ],
  )
}

pub fn surreal_response_decoder(
  decoder: decode.Decoder(a),
) -> decode.Decoder(SurrealResponse(a)) {
  use status <- decode.field("status", decode.string)

  case status {
    "OK" -> {
      use time <- decode.field("time", decode.string)
      use type_ <- decode.field("type", decode.optional(decode.string))
      use result <- decode.field("result", decode.optional(decoder))

      decode.success(SurrealResponse(time, type_, result))
    }
    "ERR" -> {
      use time <- decode.field("time", decode.string)
      use type_ <- decode.field("type", decode.optional(decode.string))
      use kind <- decode.field("kind", decode.string)
      use details <- decode.optional_field(
        "details",
        dynamic.nil(),
        decode.dynamic,
      )
      use result <- decode.field("result", decode.string)

      decode.success(SurrealErrorResponse(kind, type_, time, details, result))
    }
    _ ->
      decode.failure(
        SurrealResponse("", option.None, option.None),
        "Invalid status '" <> status <> "'",
      )
  }
}

pub fn surreal_error_decoder() -> decode.Decoder(SurrealError) {
  use code <- decode.field("code", decode.int)
  use details <- decode.field("details", decode.string)
  use description <- decode.field("description", decode.string)
  use information <- decode.field("information", decode.string)

  decode.success(ErrorResponse(code, details, description, information))
}

pub fn status(connection: Connection) -> Bool {
  result.unwrap(
    {
      use req <- result.try(request.to(connection.endpoint <> "/status"))
      use resp <- result.try(
        httpc.send(
          req
          |> request.set_method(http.Get)
          |> request.set_header("Keep-Alive", "timeout=5, max=1000")
          |> request.set_header("Surreal-DB", connection.database)
          |> request.set_header("Surreal-NS", connection.namespace)
          |> request.set_header("Authorization", connection.authorization),
        )
        |> result.map_error(fn(_) { Nil }),
      )

      Ok(resp.status == 200)
    },
    False,
  )
}

pub type SurrealError {
  InvalidUrl
  HttpError(httpc.HttpError)
  ErrorResponse(
    code: Int,
    details: String,
    description: String,
    information: String,
  )
  FailedToDecode(json.DecodeError)
  NoResponse
}
