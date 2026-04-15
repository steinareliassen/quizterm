import backend/roomhandler
import backend/sockethandler
import backend/statehandler
import gleam/bytes_tree
import gleam/erlang/application
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam/string
import mist.{type ResponseData}
import web/components/answerlist
import web/components/card
import web/components/control
import web/router
import wisp
import wisp/wisp_mist
import envoy

pub fn main() {
  wisp.configure_logger()

  let assert Ok(sha_api_key) = envoy.get("SHAED_API_KEY")
  let assert Ok(secret) = envoy.get("QTERM_SECRET")

  let assert Ok(state_handler) = statehandler.initialize()
  let assert Ok(room_handler) = roomhandler.initialize(state_handler)

  let assert Ok(_) =
    fn(req: request.Request(mist.Connection)) {
      case req.method {
        // Filter out Head requests, 
        http.Head ->
          response.new(200)
          |> response.set_body(mist.Bytes(bytes_tree.new()))
        _ ->
          case request.path_segments(req) {
            ["lustre", "runtime.mjs"] -> serve_runtime()
            ["client.js"] -> serve_static("client.js")
            ["static", file] -> serve_static(file)
            ["socket", "live", id, pin] ->
              sockethandler.serve(req, card.component(), id, pin, room_handler)
            ["socket", "control", id, pin] ->
              sockethandler.serve(
                req,
                control.component(),
                id,
                pin,
                room_handler,
              )
            ["socket", "single", id, pin] ->
              sockethandler.serve_single(
                req,
                answerlist.component(),
                id,
                pin,
                room_handler,
                state_handler,
              )
            _ ->
              wisp_mist.handler(
                router.handle_request(sha_api_key, room_handler, state_handler, _),
                secret,
              )(req)
          }
      }
    }
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(1234)
    |> mist.start

  process.sleep_forever()
}

fn serve_static(filename: String) {
  let assert Ok(priv) = application.priv_directory("quizterm")
  let surname = string.split(filename, ".") |> list.last
  let path = priv <> "/static/" <> filename
  let data =
    mist.send_file(path, offset: 0, limit: None)
    |> result.map(fn(file) {
      response.new(200)
      |> response.set_header("Content-Type", case surname {
        Ok("css") -> "text/css"
        Ok("js") -> "application/javascript"
        Ok(_) | Error(_) -> "text/html"
      })
      |> response.set_body(file)
    })
    |> result.lazy_unwrap(fn() {
      response.new(404)
      |> response.set_body(
        bytes_tree.from_string("Requested resource not found") |> mist.Bytes,
      )
    })

  data
}

fn serve_runtime() -> Response(ResponseData) {
  let assert Ok(lustre_priv) = application.priv_directory("lustre")
  let file_path = lustre_priv <> "/static/lustre-server-component.mjs"

  case mist.send_file(file_path, offset: 0, limit: None) {
    Ok(file) ->
      response.new(200)
      |> response.prepend_header("content-type", "application/javascript")
      |> response.set_body(file)

    Error(_) ->
      response.new(404)
      |> response.set_body(mist.Bytes(bytes_tree.new()))
  }
}
