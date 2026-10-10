import gjwt
import gjwt/header
import gjwt/key
import gjwt/payload
import gleam/bool
import gleam/dynamic
import gleam/dynamic/decode
import gleam/float
import gleam/order
import gleam/result
import gleam/time/timestamp

/// The payload structure for JWT authentication, containing standard claims and custom fields.
pub type Payload {
  Payload(
    issued_at: timestamp.Timestamp,
    not_valid_before: timestamp.Timestamp,
    expire_at: timestamp.Timestamp,
    issuer: String,
    jwt_id: String,
    namespace: String,
    database: String,
    access: String,
    id: String,
  )
}

/// A decoder for a timestamp represented as an integer in seconds since the Unix epoch. It 
/// converts the integer to a `timestamp.Timestamp` type.
fn int_time_decoder() -> decode.Decoder(timestamp.Timestamp) {
  decode.map(decode.int, timestamp.from_unix_seconds)
}

/// Verifies a JWT string using the provided key. It checks the signature, extracts claims, and 
/// validates the token's timing constraints.
pub fn verify_jwt(jwt: String, key: key.Key) -> Result(Payload, Nil) {
  use <- bool.guard(!gjwt.verify(jwt, key), Error(Nil))

  use data <- result.try(gjwt.from_jwt(jwt, key))
  let #(_header, payload) = data

  use issued_at <- result.try(
    payload.get_claim(payload, "iat", int_time_decoder())
    |> result.replace_error(Nil),
  )
  use not_valid_before <- result.try(
    payload.get_claim(payload, "nbf", int_time_decoder())
    |> result.replace_error(Nil),
  )
  use expire_at <- result.try(
    payload.get_claim(payload, "exp", int_time_decoder())
    |> result.replace_error(Nil),
  )
  use issuer <- result.try(
    payload.get_claim(payload, "iss", decode.string)
    |> result.replace_error(Nil),
  )
  use jwt_id <- result.try(
    payload.get_claim(payload, "jti", decode.string)
    |> result.replace_error(Nil),
  )
  use namespace <- result.try(
    payload.get_claim(payload, "NS", decode.string)
    |> result.replace_error(Nil),
  )
  use database <- result.try(
    payload.get_claim(payload, "DB", decode.string)
    |> result.replace_error(Nil),
  )
  use access <- result.try(
    payload.get_claim(payload, "AC", decode.string)
    |> result.replace_error(Nil),
  )
  use id <- result.try(
    payload.get_claim(payload, "ID", decode.string)
    |> result.replace_error(Nil),
  )

  use <- bool.guard(
    timestamp.compare(timestamp.system_time(), not_valid_before) == order.Lt,
    Error(Nil),
  )

  use <- bool.guard(
    timestamp.compare(timestamp.system_time(), expire_at) == order.Gt,
    Error(Nil),
  )

  Ok(Payload(
    issued_at,
    not_valid_before,
    expire_at,
    issuer,
    jwt_id,
    namespace,
    database,
    access,
    id,
  ))
}

/// Generates a JWT token with the given payload and signs it using the provided key. It 
/// constructs the JWT header and payload, then signs the token to produce a JWT string.
pub fn generate_jwt(payload: Payload, key: key.Key) -> String {
  let gjwt_payload =
    payload.new()
    |> payload.add_claim(#(
      "iat",
      dynamic.int(
        payload.issued_at
        |> timestamp.to_unix_seconds
        |> float.floor
        |> float.round,
      ),
    ))
    |> payload.add_claim(#(
      "nbf",
      dynamic.int(
        payload.not_valid_before
        |> timestamp.to_unix_seconds
        |> float.floor
        |> float.round,
      ),
    ))
    |> payload.add_claim(#(
      "exp",
      dynamic.int(
        payload.expire_at
        |> timestamp.to_unix_seconds
        |> float.floor
        |> float.round,
      ),
    ))
    |> payload.add_claim(#("iss", dynamic.string(payload.issuer)))
    |> payload.add_claim(#("jti", dynamic.string(payload.jwt_id)))
    |> payload.add_claim(#("NS", dynamic.string(payload.namespace)))
    |> payload.add_claim(#("DB", dynamic.string(payload.database)))
    |> payload.add_claim(#("AC", dynamic.string(payload.access)))
    |> payload.add_claim(#("ID", dynamic.string(payload.id)))

  let header =
    header.new()
    |> header.add_entry(#("alg", dynamic.string(key.algorithm)))
    |> header.add_entry(#("typ", dynamic.string("JWT")))

  gjwt.sign_off(#(header, gjwt_payload), key)
}
