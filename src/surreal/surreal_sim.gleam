import exception
import gleam/bit_array
import gleam/erlang/charlist
import gleam/erlang/port
import gleam/erlang/process
import gleam/int
import gleam/result
import gleam/string
import sceall
import surreal

//-----------------------------------------------------------------------------------------------//
//                                      Internal Functions                                       //
//-----------------------------------------------------------------------------------------------//

@external(erlang, "test_ffi", "os_pid")
fn get_os_pid(port: port.Port) -> Result(Int, Nil)

@external(erlang, "os", "cmd")
fn os_cmd(command: charlist.Charlist) -> charlist.Charlist

//-----------------------------------------------------------------------------------------------//
//                                           Memory DB                                           //
//-----------------------------------------------------------------------------------------------//

/// Start a surrealDB instance in memory with the username and password set to `root`. 
fn start() {
  let assert Ok(handle) =
    sceall.spawn_program(
      executable_path: "/opt/homebrew/bin/surreal",
      working_directory: "",
      command_line_arguments: [
        "start",
        "--no-banner",
        "--user",
        "root",
        "--pass",
        "root",
      ],
      environment_variables: [],
    )
    as "Failed to start SurrealDB"

  let selector =
    process.new_selector() |> sceall.select(handle, fn(message) { message })

  let assert Ok(_) = receive_until_started(selector)
    as "Failed to receive SurrealDB started message"

  let failed =
    process.selector_receive(selector, 100)
    |> result.map(fn(msg) {
      case msg {
        sceall.Data(data:, ..) -> {
          bit_array.to_string(data)
          |> result.map(string.contains(
            _,
            "Address already in use (os error 48)",
          ))
          |> result.unwrap(False)
        }
        _ -> False
      }
    })
    |> result.unwrap(False)

  assert !failed as "SurrealDB failed to start, address already in use"

  handle
}

/// Receive messages from the selector until we get a message indicating that SurrealDB has started.
fn receive_until_started(
  selector: process.Selector(sceall.ProgramMessage),
) -> Result(Nil, Nil) {
  use message <- result.try(process.selector_receive(selector, 1000))

  case message {
    sceall.Data(data:, ..) -> {
      let continue =
        bit_array.to_string(data)
        |> result.map(fn(str) {
          !string.contains(str, "Started web server on ")
        })
        |> result.unwrap(True)

      case continue {
        True -> receive_until_started(selector)
        False -> Ok(Nil)
      }
    }
    sceall.Exited(..) -> Error(Nil)
  }
}

/// Terminate a surrealDB instance.
fn terminate(program: sceall.ProgramHandle) -> Nil {
  case get_os_pid(sceall.program_port(program)) {
    Ok(pid) -> {
      let _ = os_cmd(charlist.from_string("kill -TERM " <> int.to_string(pid)))
      Nil
    }
    Error(Nil) -> Nil
  }
}

pub fn connection() -> surreal.Connection {
  surreal.connection("http://localhost:8000", "main", "main", "root", "root")
}

/// Run a function with a surrealDB instance running in memory. The properties of the database are
/// passed through the connection parameter.
/// 
/// This should only be used for testing purposes and may potentially be unsafe.
pub fn with_surreal_db(next: fn(surreal.Connection) -> a) -> a {
  let handle = start()
  use <- exception.defer(fn() { terminate(handle) })

  next(connection())
}
