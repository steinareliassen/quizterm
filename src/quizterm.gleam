import backend/sockethandler
import backend/statehandler
import components/card
import components/control
import gleam/bytes_tree
import gleam/erlang/application
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/option.{None}
import gleam/otp/actor
import gleam/result
import group_registry
import lustre/attribute
import lustre/element
import lustre/element/html.{
  body, div, head, html, img, link, meta, script, title,
}
import lustre/server_component
import mist.{type Connection, type ResponseData}

pub fn main() {
  let name = process.new_name("quiz-registry")
  let assert Ok(actor.Started(data: registry, ..)) = group_registry.start(name)
  let assert Ok(actor) = statehandler.initialize(registry)
  let assert Ok(_) =
    fn(request: Request(Connection)) -> Response(ResponseData) {
      case request.path_segments(request) {
        [] -> serve_html(False)
        ["control"] -> serve_html(True)
        ["lustre", "runtime.mjs"] -> serve_runtime()
        ["static", file] -> serve_static(file)
        ["ws"] ->
          sockethandler.serve(request, card.component(), #(registry, actor))
        ["cws"] ->
          sockethandler.serve(request, control.component(), #(registry, actor))
        _ -> response.set_body(response.new(404), mist.Bytes(bytes_tree.new()))
      }
    }
    |> mist.new
    |> mist.bind("localhost")
    |> mist.port(1234)
    |> mist.start

  process.sleep_forever()
}

fn serve_html(control: Bool) -> Response(ResponseData) {
  let html =
    html([attribute.lang("en")], [
      head([], [
        link([
          attribute.rel("stylesheet"),
          attribute.type_("text/css"),
          attribute.href("/static/layout.css"),
        ]),
        meta([attribute.charset("utf-8")]),
        meta([
          attribute.name("viewport"),
          attribute.content("width=device-width, initial-scale=1"),
        ]),
        title([], "Quizterm"),
        script(
          [attribute.type_("module"), attribute.src("/lustre/runtime.mjs")],
          "",
        ),
      ]),
      body([], [
        case control {
          False -> server_component.element([server_component.route("/ws")], [])
          True ->
            div([], [
              server_component.element([server_component.route("/ws")], []),
              server_component.element([server_component.route("/cws")], []),
            ])
        },
        div([attribute.class("under")], [
          div([attribute.class("under_cell_nb")], []),
          div([attribute.class("under_cell_nb")], []),
          div([attribute.class("under_cell_bn")], [
            img([
              attribute.src("https://gleam.run/images/lucy/lucydebugfail.svg"),
              attribute.width(150),
            ]),
          ]),
        ]),
      ]),
    ])
    |> element.to_document_string_tree
    |> bytes_tree.from_string_tree

  response.new(200)
  |> response.set_body(mist.Bytes(html))
  |> response.set_header("content-type", "text/html")
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
