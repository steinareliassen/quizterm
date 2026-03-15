import gleam/erlang/process.{type Subject}
import gleam/option.{None, Some}
import gleam/otp/actor.{type Started}
import lustre/attribute.{class}
import lustre/element
import lustre/element/html.{body, div, head, html, link, meta, script, title}
import lustre/server_component
import shared/message.{
  type ClientsServer, type RoomControl, CreateRoom, FetchRoom,
}
import web.{middleware}
import wisp.{type Request, type Response}

pub fn handle_request(
  actor: actor.Started(Subject(RoomControl(ClientsServer))),
  req: Request,
) -> Response {
  use req <- middleware(req)
  case wisp.path_segments(req) {
    ["board", id, "slow"] -> handle_slow(actor, id) |> serve_html
    ["board", id] -> handle_board(actor, id, False) |> serve_html
    ["board", id, "control"] -> handle_board(actor, id, True) |> serve_html
    ["room", id] -> {
      process.send(actor.data, CreateRoom(id))
      status_head("Created room with id " <> id)
      |> serve_html()
    }
    _ -> status_head("Nothing to see here") |> serve_html
  }
}

fn status_head(output: String) {
  fn() -> element.Element(a) {
    html.div([class("terminal-header")], [
      html.div([class("terminal-status")], [
        html.span([class("status-blink")], [html.text("●")]),
        html.h2([class("ml-8")], [html.text(output)]),
      ]),
    ])
  }
}

fn handle_slow(
  actor: Started(Subject(RoomControl(ClientsServer))),
  id: String,
) -> fn() -> element.Element(a) {
  let start_args = actor.call(actor.data, 1000, FetchRoom(id, _))
  case start_args {
    Some(_) -> fn() {
      div([], [
        server_component.element(
          [server_component.route("/socket/slow/" <> id)],
          [],
        ),
      ])
    }
    None -> status_head("Could not find that room...")
  }
}

fn handle_board(
  actor: Started(Subject(RoomControl(ClientsServer))),
  id: String,
  control: Bool,
) -> fn() -> element.Element(a) {
  let start_args = actor.call(actor.data, 1000, FetchRoom(id, _))
  case start_args {
    Some(_) -> fn() {
      div([], [
        server_component.element(
          [server_component.route("/socket/card/" <> id)],
          [],
        ),
        case control {
          True ->
            server_component.element(
              [server_component.route("/socket/control/" <> id)],
              [],
            )
          False -> element.none()
        },
      ])
    }
    None -> status_head("Could not find that room...")
  }
}

fn serve_html(content: fn() -> element.Element(a)) -> Response {
  let html =
    html([], [
      head([], [
        meta([attribute.charset("utf-8")]),
        meta([
          attribute.name("viewport"),
          attribute.content("width=device-width, initial-scale=1.0"),
        ]),
        title([], "QUIZTERMINAL v1.0"),
        script(
          [attribute.type_("module"), attribute.src("/lustre/runtime.mjs")],
          "",
        ),
        link([
          attribute.rel("stylesheet"),
          attribute.type_("text/css"),
          attribute.href("/static/layout.css"),
        ]),
      ]),
      body([], [
        div([class("terminal-screen")], [
          div([class("terminal-glow")], [
            div([class("scanlines")], []),

            // title
            div([class("terminal-header")], [
              html.pre([class("terminal-title")], [
                html.text(
                  "
╔═══════════════════════════════════════╗
║       Q U I Z T E R M I N A L         ║
╚═══════════════════════════════════════╝
",
                ),
              ]),
            ]),
            // Insert content
            content(),
          ]),
        ]),
      ]),
    ])
    |> element.to_document_string

  wisp.html_response(html, 200)
}
