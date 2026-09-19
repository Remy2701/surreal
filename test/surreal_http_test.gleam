import birdie
import gleam/bool
import gleam/dynamic/decode
import gleam/http
import gleam/list
import gleam/option
import gleam/pair
import gleam/string
import gleeunit/should
import http/surreal_http
import surreal
import surreal/identifier
import surreal/response
import surreal/surreal_sim
import surreal_ql
import surreal_test

// TODO: Move surreal_http and surreal_wss to surreal/

//-----------------------------------------------------------------------------------------------//
//                                          GET /status                                          //
//-----------------------------------------------------------------------------------------------//

pub fn status_request_test() {
  let connection =
    surreal.connection(
      endpoint: "http://localhost:8000",
      namespace: "namespace",
      database: "database",
      username: "user",
      password: "password",
    )

  let request =
    connection
    |> surreal_http.status_request()
    |> should.be_ok()

  assert request.scheme == http.Http as "Invalid scheme"
  assert request.host == "localhost"
  assert option.Some(8000) == request.port as "Invalid port"
  assert request.method == http.Get as "Invalid method"
  assert request.path == "/status" as "Invalid path"
  assert list.contains(request.headers, #("surreal-db", "database"))
    as "Missing Surreal-DB header"
  assert list.contains(request.headers, #("surreal-ns", "namespace"))
    as "Missing Surreal-NS header"
  assert list.contains(request.headers, #(
    "authorization",
    connection.authorization,
  ))
    as "Missing Authorization header"

  Nil
}

pub fn status_test() {
  use <- bool.guard(!surreal_test.run_http_test, Nil)
  use connection <- surreal_sim.with_surreal_db()

  connection
  |> surreal_http.status()
  |> should.be_ok()

  Nil
}

//-----------------------------------------------------------------------------------------------//
//                                          GET /health                                          //
//-----------------------------------------------------------------------------------------------//

pub fn health_test() {
  use <- bool.guard(!surreal_test.run_http_test, Nil)
  use connection <- surreal_sim.with_surreal_db()

  connection
  |> surreal_http.health()
  |> should.be_ok()

  Nil
}

//-----------------------------------------------------------------------------------------------//
//                                          GET /ready                                           //
//-----------------------------------------------------------------------------------------------//

pub fn ready_test() {
  use <- bool.guard(!surreal_test.run_http_test, Nil)
  use <- bool.guard(True, Nil)
  // Disable since requires > v3.2.0
  use connection <- surreal_sim.with_surreal_db()

  connection
  |> surreal_http.ready()
  |> should.be_ok()

  Nil
}

//-----------------------------------------------------------------------------------------------//
//                                         GET /version                                          //
//-----------------------------------------------------------------------------------------------//

pub fn version_test() {
  use <- bool.guard(!surreal_test.run_http_test, Nil)
  use connection <- surreal_sim.with_surreal_db()

  connection
  |> surreal_http.version()
  |> should.be_ok()
  |> birdie.snap("GET /version")

  Nil
}

//-----------------------------------------------------------------------------------------------//
//                                         POST /signin                                          //
//-----------------------------------------------------------------------------------------------//

// TODO

//-----------------------------------------------------------------------------------------------//
//                                         POST /signup                                          //
//-----------------------------------------------------------------------------------------------//

// TODO

//-----------------------------------------------------------------------------------------------//
//                                        GET /key/:table                                        //
//-----------------------------------------------------------------------------------------------//

// TODO

//-----------------------------------------------------------------------------------------------//
//                                       POST /key/:table                                        //
//-----------------------------------------------------------------------------------------------//

pub fn post_record_test() {
  use <- bool.guard(!surreal_test.run_http_test, Nil)
  use connection <- surreal_sim.with_surreal_db()

  // Create the table and field if they don't exist
  connection
  |> surreal_http.run_sql(
    "DEFINE TABLE IF NOT EXISTS user SCHEMAFULL TYPE NORMAL;"
      <> "DEFINE FIELD IF NOT EXISTS name ON TABLE user TYPE string;",
    [],
    decode.dynamic,
  )
  |> should.be_ok()

  // Create a record with a specific ID
  connection
  |> surreal_http.post_record(
    "user",
    should.be_ok(identifier.from_string("user:lucy")),
    surreal_ql.Object([#("name", surreal_ql.String("Lucy"))]),
    {
      use id <- decode.field("id", decode.string)
      use name <- decode.field("name", decode.string)

      decode.success(#(id, name))
    },
  )
  |> should.be_ok()
  |> list.flat_map(fn(data) {
    data
    |> surreal.should_be_success()
    |> should.be_some()
  })
  |> should.equal([#("user:lucy", "Lucy")])

  // Creating the same record  should result in an error
  connection
  |> surreal_http.post_record(
    "user",
    should.be_ok(identifier.from_string("user:lucy")),
    surreal_ql.Object([#("name", surreal_ql.String("Lucy"))]),
    {
      use id <- decode.field("id", decode.string)
      use name <- decode.field("name", decode.string)

      decode.success(#(id, name))
    },
  )
  |> should.be_ok()
  |> list.map(fn(data) {
    data
    |> surreal.should_be_error()
  })

  Nil
}

//-----------------------------------------------------------------------------------------------//
//                                           POST /sql                                           //
//-----------------------------------------------------------------------------------------------//

pub fn run_sql_test() {
  use <- bool.guard(!surreal_test.run_http_test, Nil)
  use connection <- surreal_sim.with_surreal_db()

  // Create the table and field if they don't exist
  connection
  |> surreal_http.run_sql(
    "DEFINE TABLE IF NOT EXISTS user SCHEMAFULL TYPE NORMAL;\n"
      <> "DEFINE FIELD IF NOT EXISTS name ON TABLE user TYPE string;\n"
      <> "DEFINE FIELD IF NOT EXISTS age ON TABLE user TYPE int;\n"
      <> "\n"
      <> "DEFINE INDEX IF NOT EXISTS age_index ON TABLE user FIELDS age;",
    [],
    decode.dynamic,
  )
  |> should.be_ok()

  // Retrieve the info of the table to verify it was executed correctly.
  let res =
    connection
    |> surreal_http.run_sql(
      "INFO FOR TABLE user;",
      [],
      response.info_table_response_decoder(),
    )
    |> should.be_ok()
  let assert [res] = res
    as "Expected a single response from the INFO FOR TABLE command"
  let assert surreal.SurrealResponse(result:, ..) = res
    as "Expected a successful response from the INFO FOR TABLE command"
  let assert option.Some(info) = result
    as "Expected a result from the INFO FOR TABLE command"
  assert list.sort(list.map(info.fields, pair.first), string.compare)
    == ["age", "name"]
    as "Expected the INFO FOR TABLE command to return the correct fields"

  assert list.sort(list.map(info.indexes, pair.first), string.compare)
    == ["age_index"]
    as "Expected the INFO FOR TABLE command to return the correct indexes"

  Nil
}
