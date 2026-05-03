import components.{terminal_header}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import lustre/attribute.{class}
import lustre/element
import lustre/element/html.{body, div, head, html, link, meta, script, title}
import lustre/server_component.{route}
import shared/message.{RoomInfo}
import wisp.{type Response}

pub fn direct_html(
  rooms: List(#(String, message.RoomInfo)),
  room_key: String,
) -> Response {
  let maybe_room =
    list.find(rooms, fn(room) {
      let #(_, RoomInfo(_, _, maybe_room_key)) = room
      case maybe_room_key {
        None -> False
        Some(actual_room_key) -> room_key == actual_room_key
      }
    })

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
      script([attribute.type_("module"), attribute.src("/client.js")], ""),
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
          server_component.element(
            [
              case maybe_room {
                Ok(#(room, message.RoomInfo(_, _, Some(room_key)))) ->
                  server_component.route(
                    "/socket/game/" <> room <> "/key/" <> room_key,
                  )
                _ -> server_component.route("/socket/roomconnect/" <> room_key)
              },
            ],
            [],
          ),
        ]),
      ]),
    ]),
  ])
  |> element.to_document_string
  |> wisp.html_response(200)
}

pub fn main_html(rooms: List(#(String, message.RoomInfo))) -> Response {
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
      script([attribute.type_("module"), attribute.src("/client.js")], ""),
      script(
        [
          attribute.id("model"),
          attribute.type_("application/json"),
        ],
        json.array(rooms, fn(room) {
          let #(id, RoomInfo(name, pin_enc, _)) = room
          json.object([
            #("id", json.string(id)),
            #("name", json.string(name)),
            #("key", json.string(pin_enc)),
          ])
        })
          |> json.to_string,
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
          html.div([attribute.id("app")], []),
        ]),
      ]),
    ]),
  ])
  |> element.to_document_string
  |> wisp.html_response(200)
}

// Todo: join with main_html
pub fn html_404() -> Response {
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
║           4       0       4           ║
╚═════════════════════════════════ohno!═╝
",
              ),
            ]),
          ]),
        ]),
      ]),
    ]),
  ])
  |> element.to_document_string
  |> wisp.html_response(400)
}

pub fn create_json_response(response: #(Int, String, String)) {
  let #(code, message, output) = response
  wisp.log_info("[api][" <> int.to_string(code) <> "][" <> message <> "]")
  json.object([#("response", json.string(output))])
  |> json.to_string
  |> wisp.json_response(200)
}

pub fn status_head(output: String) {
  fn() -> element.Element(a) { html.text(output) |> terminal_header }
}
