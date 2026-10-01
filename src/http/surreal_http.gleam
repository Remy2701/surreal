import gleam/dynamic/decode
import gleam/http
import gleam/http/request.{type Request}
import gleam/httpc
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import surreal.{type Connection, type SurrealError, type SurrealResponse}
import surreal/identifier.{type Identifier}
import surreal_ql

/// Applies the necessary headers to the HTTP request based on the SurrealDB connection.
/// This includes setting the "Keep-Alive", "Surreal-DB", "Surreal-NS", "Authorization", and "Accept" headers.
fn apply_headers(req: Request(body), connection: Connection) -> Request(body) {
  req
  |> request.set_header("Keep-Alive", "timeout=5, max=1000")
  |> request.set_header("Surreal-DB", connection.database)
  |> request.set_header("Surreal-NS", connection.namespace)
  |> request.set_header("Authorization", connection.authorization)
  |> request.set_header("Accept", "application/json")
}

fn endpoint(
  connection: Connection,
  path: String,
) -> Result(Request(String), Nil) {
  request.to(connection.endpoint <> path)
  |> result.replace_error(Nil)
}

//-----------------------------------------------------------------------------------------------//
//                                          GET /status                                          //
//-----------------------------------------------------------------------------------------------//

/// The status endpoint returns a simple response indicating the status of the SurrealDB server.
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#status
pub fn status_request(connection: Connection) -> Result(Request(String), Nil) {
  use req <- result.try(endpoint(connection, "/status"))

  req
  |> request.set_method(http.Get)
  |> apply_headers(connection)
  |> Ok
}

/// The status endpoint returns a simple response indicating the status of the SurrealDB server.
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#status
pub fn status(connection: Connection) -> Result(Nil, Nil) {
  use req <- result.try(status_request(connection))

  use resp <- result.try(httpc.send(req) |> result.replace_error(Nil))

  case resp.status {
    200 -> Ok(Nil)
    _ -> Error(Nil)
  }
}

//-----------------------------------------------------------------------------------------------//
//                                          GET /health                                          //
//-----------------------------------------------------------------------------------------------//

/// The health endpoint returns a simple response indicating the health of the SurrealDB server.
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#health
pub fn health_request(connection: Connection) -> Result(Request(String), Nil) {
  use req <- result.try(endpoint(connection, "/health"))

  req
  |> request.set_method(http.Get)
  |> apply_headers(connection)
  |> Ok
}

/// The health endpoint returns a simple response indicating the health of the SurrealDB server.
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#health
pub fn health(connection: Connection) -> Result(Nil, Nil) {
  use req <- result.try(health_request(connection))

  use resp <- result.try(httpc.send(req) |> result.replace_error(Nil))

  case resp.status {
    200 -> Ok(Nil)
    _ -> Error(Nil)
  }
}

//-----------------------------------------------------------------------------------------------//
//                                          GET /ready                                           //
//-----------------------------------------------------------------------------------------------//

/// The ready endpoint returns a simple response indicating the readiness of the SurrealDB server.
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#ready
pub fn ready_request(connection: Connection) -> Result(Request(String), Nil) {
  use req <- result.try(endpoint(connection, "/ready"))

  req
  |> request.set_method(http.Get)
  |> apply_headers(connection)
  |> Ok
}

/// The ready endpoint returns a simple response indicating the readiness of the SurrealDB server.
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#ready
pub fn ready(connection: Connection) -> Result(Nil, Nil) {
  use req <- result.try(ready_request(connection))

  use resp <- result.try(httpc.send(req) |> result.replace_error(Nil))

  case resp.status {
    200 -> Ok(Nil)
    _ -> Error(Nil)
  }
}

//-----------------------------------------------------------------------------------------------//
//                                         GET /version                                          //
//-----------------------------------------------------------------------------------------------//

/// The version endpoint returns the current version of the SurrealDB server.
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#version
pub fn version_request(
  connection: Connection,
) -> Result(Request(String), SurrealError) {
  use req <- result.try(
    endpoint(connection, "/version")
    |> result.replace_error(surreal.InvalidUrl),
  )

  req
  |> request.set_method(http.Get)
  |> apply_headers(connection)
  |> Ok
}

/// The version endpoint returns the current version of the SurrealDB server.
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#version
pub fn version(connection: Connection) -> Result(String, SurrealError) {
  use req <- result.try(version_request(connection))

  use resp <- result.try(httpc.send(req) |> result.map_error(surreal.HttpError))

  case resp.status {
    200 -> Ok(resp.body)
    _ ->
      Error(surreal.ErrorResponse(
        code: resp.status,
        details: "",
        description: "",
        information: resp.body,
      ))
  }
}

//-----------------------------------------------------------------------------------------------//
//                                         POST /signin                                          //
//-----------------------------------------------------------------------------------------------//

pub type AuthenticationBody {
  AuthenticationBody(
    db: String,
    ns: String,
    ac: String,
    email: String,
    password: String,
    data: List(#(String, surreal_ql.SurrealQL)),
  )
}

pub fn authentication_body(
  connection: Connection,
  table: String,
  email: String,
  password: String,
  content: List(#(String, surreal_ql.SurrealQL)),
) -> AuthenticationBody {
  AuthenticationBody(
    db: connection.database,
    ns: connection.namespace,
    ac: table,
    email: email,
    password: password,
    data: content,
  )
}

fn authentication_body_to_surql(
  body: AuthenticationBody,
) -> surreal_ql.SurrealQL {
  surreal_ql.Object([
    #("db", surreal_ql.String(body.db)),
    #("ns", surreal_ql.String(body.ns)),
    #("ac", surreal_ql.String(body.ac)),
    #("email", surreal_ql.String(body.email)),
    #("password", surreal_ql.String(body.password)),
    ..body.data
  ])
}

/// Access an existing account inside the SurrealDB database server.
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#signin
pub fn signin_request(
  connection: Connection,
  body: AuthenticationBody,
) -> Result(Request(String), SurrealError) {
  use req <- result.try(
    endpoint(connection, "/signin")
    |> result.replace_error(surreal.InvalidUrl),
  )

  req
  |> request.set_method(http.Post)
  |> apply_headers(connection)
  |> request.set_body(
    body
    |> authentication_body_to_surql
    |> surreal_ql.to_string(),
  )
  |> Ok
}

/// Access an existing account inside the SurrealDB database server.
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#signin
pub fn signin(
  connection: Connection,
  table: String,
  email: String,
  password: String,
  content: List(#(String, surreal_ql.SurrealQL)),
) -> Result(String, surreal.SurrealError) {
  use req <- result.try(
    authentication_body(connection, table, email, password, content)
    |> signin_request(connection, _),
  )

  use resp <- result.try(httpc.send(req) |> result.map_error(surreal.HttpError))

  json.parse(resp.body, surreal.auth_result_decoder())
  |> result.map_error(surreal.FailedToDecode)
  |> result.flatten()
}

//-----------------------------------------------------------------------------------------------//
//                                         POST /signup                                          //
//-----------------------------------------------------------------------------------------------//

/// Create an account inside the SurrealDB database server.
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#signup
pub fn signup_request(
  connection: Connection,
  body: AuthenticationBody,
) -> Result(Request(String), SurrealError) {
  use req <- result.try(
    endpoint(connection, "/signup")
    |> result.replace_error(surreal.InvalidUrl),
  )

  req
  |> request.set_method(http.Post)
  |> apply_headers(connection)
  |> request.set_body(
    body
    |> authentication_body_to_surql
    |> surreal_ql.to_string(),
  )
  |> Ok
}

/// Create an account inside the SurrealDB database server.
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#signup
pub fn signup(
  connection: Connection,
  table: String,
  email: String,
  password: String,
  content: List(#(String, surreal_ql.SurrealQL)),
) -> Result(String, surreal.SurrealError) {
  use req <- result.try(
    authentication_body(connection, table, email, password, content)
    |> signup_request(connection, _),
  )

  use resp <- result.try(httpc.send(req) |> result.map_error(surreal.HttpError))

  json.parse(resp.body, surreal.auth_result_decoder())
  |> result.map_error(surreal.FailedToDecode)
  |> result.flatten()
}

//-----------------------------------------------------------------------------------------------//
//                                        GET /key/:table                                        //
//-----------------------------------------------------------------------------------------------//

/// The endpoint to select all records in a specific table in the database.
/// 
/// The equivalent query is:
/// ```surrealql
/// SELECT * FROM type::table($table);
/// ```
/// 
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#get-table
pub fn get_records(
  connection: Connection,
  table: String,
  decoder: decode.Decoder(a),
) -> Result(List(SurrealResponse(List(a))), surreal.SurrealError) {
  use req <- result.try(
    request.to(connection.endpoint <> "/key/" <> table)
    |> result.replace_error(surreal.InvalidUrl),
  )
  use resp <- result.try(
    httpc.send(
      req
      |> request.set_method(http.Get)
      |> apply_headers(connection),
    )
    |> result.map_error(surreal.HttpError),
  )

  resp.body
  |> json.parse(surreal.result_decoder(decode.list(decoder)))
  |> result.map_error(surreal.FailedToDecode)
  |> result.flatten()
}

//-----------------------------------------------------------------------------------------------//
//                                       POST /key/:table                                        //
//-----------------------------------------------------------------------------------------------//

/// The endpoint to create a new record in a specific table in the database.
/// 
/// The equivalent query is:
/// ```surrealql
/// CREATE type::table($table) CONTENT $data;
/// ```
/// 
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#post-table
pub fn post_table(
  connection: Connection,
  table: String,
  content: surreal_ql.SurrealQL,
  decoder: decode.Decoder(a),
) -> Result(List(SurrealResponse(List(a))), surreal.SurrealError) {
  use req <- result.try(
    request.to(connection.endpoint <> "/key/" <> table)
    |> result.replace_error(surreal.InvalidUrl),
  )
  use resp <- result.try(
    httpc.send(
      req
      |> request.set_method(http.Post)
      |> request.set_body(surreal_ql.to_json(content) |> json.to_string())
      |> apply_headers(connection),
    )
    |> result.map_error(surreal.HttpError),
  )

  resp.body
  |> json.parse(surreal.result_decoder(decode.list(decoder)))
  |> result.map_error(surreal.FailedToDecode)
  |> result.flatten()
}

//-----------------------------------------------------------------------------------------------//
//                                      GET /key/:table/:id                                      //
//-----------------------------------------------------------------------------------------------//

/// The get record endpoint selects a specific record in a specific table in the database.
/// 
/// The equivalent query is:
/// ```surrealql
/// SELECT * FROM type::record($table, $id);
/// ```
/// 
/// Consider using the `get_record` function instead if you don't need the raw response, as it will 
/// simplify the result handling.
/// 
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#get-record
pub fn get_record_raw(
  connection: Connection,
  table: String,
  id: Identifier(a),
  decoder: decode.Decoder(a),
) -> Result(List(SurrealResponse(List(a))), SurrealError) {
  use req <- result.try(
    request.to(
      connection.endpoint <> "/key/" <> table <> "/" <> identifier.to_string(id),
    )
    |> result.replace_error(surreal.InvalidUrl),
  )
  use resp <- result.try(
    httpc.send(
      req
      |> request.set_method(http.Get)
      |> apply_headers(connection),
    )
    |> result.map_error(surreal.HttpError),
  )

  resp.body
  |> json.parse(surreal.result_decoder(decode.list(decoder)))
  |> result.map_error(surreal.FailedToDecode)
  |> result.flatten()
}

/// The get record endpoint selects a specific record in a specific table in the database.
/// 
/// The equivalent query is:
/// ```surrealql
/// SELECT * FROM type::record($table, $id);
/// ```
/// 
/// This is the simplified version of `get_record_raw` which already extracts the result.
///
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#get-record
pub fn get_record(
  connection: Connection,
  table: String,
  id: identifier.Identifier(a),
  decoder: decode.Decoder(a),
) -> Result(a, surreal.SurrealError) {
  use result <- result.try(get_record_raw(connection, table, id, decoder))
  case result {
    [] -> Error(surreal.NoResponse)
    [first, ..] ->
      case first {
        surreal.SurrealResponse(result:, ..) ->
          result
          |> option.to_result(surreal.NoResponse)
          |> result.try(fn(result) {
            case result {
              [] -> Error(surreal.NoResponse)
              [first, ..] -> Ok(first)
            }
          })
        surreal.SurrealErrorResponse(kind:, details:, result:, ..) ->
          Error(surreal.ErrorResponse(
            200,
            string.inspect(details),
            kind,
            result,
          ))
      }
  }
}

//-----------------------------------------------------------------------------------------------//
//                                     POST /key/:table/:id                                      //
//-----------------------------------------------------------------------------------------------//

/// Creates a record in a specific table in the database.
/// 
/// The equivalent query is:
/// ```surrealql
/// CREATE type::table($id, $table) CONTENT $data;
/// ```
/// 
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#post-record
pub fn post_record(
  connection: Connection,
  table: String,
  id: identifier.Identifier(a),
  content: surreal_ql.SurrealQL,
  decoder: decode.Decoder(a),
) -> Result(List(SurrealResponse(List(a))), surreal.SurrealError) {
  use req <- result.try(
    request.to(
      connection.endpoint <> "/key/" <> table <> "/" <> identifier.to_string(id),
    )
    |> result.replace_error(surreal.InvalidUrl),
  )

  use resp <- result.try(
    httpc.send(
      req
      |> request.set_method(http.Post)
      |> apply_headers(connection)
      |> request.set_body(surreal_ql.to_string(content)),
    )
    |> result.map_error(surreal.HttpError),
  )

  resp.body
  |> json.parse(surreal.result_decoder(decode.list(decoder)))
  |> result.map_error(surreal.FailedToDecode)
  |> result.flatten()
}

//-----------------------------------------------------------------------------------------------//
//                                           POST /sql                                           //
//-----------------------------------------------------------------------------------------------//

/// The SQL endpoint enables use of SurrealQL queries.
/// 
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#sql
pub fn run_sql(
  connection: Connection,
  query: String,
  parameters: List(#(String, surreal_ql.SurrealQL)),
  decoder: decode.Decoder(a),
) -> Result(List(SurrealResponse(a)), surreal.SurrealError) {
  use req <- result.try(
    request.to(connection.endpoint <> "/sql")
    |> result.replace_error(surreal.InvalidUrl),
  )

  use resp <- result.try(
    httpc.send(
      req
      |> request.set_method(http.Post)
      |> apply_headers(connection)
      |> request.set_query(
        parameters
        |> list.map(fn(entry) { #(entry.0, surreal_ql.to_string(entry.1)) }),
      )
      |> request.set_body(query),
    )
    |> result.map_error(surreal.HttpError),
  )

  resp.body
  |> json.parse(surreal.result_decoder(decoder))
  |> result.map_error(surreal.FailedToDecode)
  |> result.flatten()
}
