import backend/roomhandler
import backend/sockethandler
import gleam/bytes_tree
import gleam/erlang/application
import gleam/erlang/process
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/option.{None}
import gleam/result
import mist.{type ResponseData}
import web/components/answerlist
import web/components/card
import web/components/control
import web/router
import wisp/wisp_mist

pub fn main() {
  let assert Ok(actor) = roomhandler.initialize()

  let assert Ok(_) =
    fn(req) {
      case request.path_segments(req) {
        ["lustre", "runtime.mjs"] -> serve_runtime()
        ["static", file] -> serve_static(file)
        ["socket", "card", id] -> {
          sockethandler.serve(req, card.component(), id, actor)
        }
        ["socket", "control", id] ->
          sockethandler.serve(req, control.component(), id, actor)
        ["socket", "slow", id] ->
          sockethandler.serve_slow(req, answerlist.component(), id, actor)
        _ ->
          wisp_mist.handler(router.handle_request(actor, _), "very_secret")(req)
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
  let path = priv <> "/" <> filename
  mist.send_file(path, offset: 0, limit: None)
  |> result.map(fn(file) {
    response.new(200)
    |> response.set_header("Content-Type", "text/css")
    |> response.set_body(file)
  })
  |> result.lazy_unwrap(fn() {
    response.new(404)
    |> response.set_body(
      bytes_tree.from_string("Requested resource not found") |> mist.Bytes,
    )
  })
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
